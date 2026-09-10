#!/usr/bin/env fish
# PATH switching, restore, and the version-file lookup contract that
# conf.d/phpenv.fish depends on.
#
# This suite exists because the two highest-severity defects found in the
# 2026-09 audit both lived here and both shipped under a green test run:
# __phpenv_find_version_file returned 0 whether or not it found anything
# (silently disabling startup PATH init), and `use system` reported success
# after a failed restore. Neither was reachable from the other suites,
# which only source functions/phpenv.fish and never touch PATH.
#
# Run: fish tests/path-management.fish

set -l repo_root (dirname (status dirname))
source $repo_root/tests/helpers.fish
source $repo_root/functions/phpenv.fish

# Keep the PWD event handler quiet while the test cds around
set -g PHPENV_AUTO_SWITCH false
set -g test_failures 0

# Redirect the shim directory into a sandbox. __phpenv_get_shim_dir reads
# XDG_DATA_HOME, so without this the failure-path assertions below touch the
# developer's real ~/.local/share/phpenv/shims.
set -l xdg_sandbox (mktemp -d 2>/dev/null; or mktemp -d -t phpenv-xdg)
set -gx XDG_DATA_HOME $xdg_sandbox

# --- __phpenv_find_version_file exit-status contract ------------------------
# conf.d branches on the status alone, so "found" must be distinguishable
# from "not found" without inspecting stdout.
set -l probe (mktemp -d 2>/dev/null; or mktemp -d -t phpenv-path)
pushd $probe

__phpenv_find_version_file .php-version >/dev/null
assert_fails $status "find_version_file: non-zero when no version file exists"

echo 8.2 >.php-version
__phpenv_find_version_file .php-version >/dev/null
assert_status $status 0 "find_version_file: zero when the version file exists"

assert_eq (__phpenv_find_version_file .php-version) "$probe/.php-version" \
    "find_version_file: prints the absolute path it found"

# Upward walk: the file lives in the parent, the cwd is a child
mkdir -p nested/deeper
pushd nested/deeper
assert_eq (__phpenv_find_version_file .php-version) "$probe/.php-version" \
    "find_version_file: walks upward from a nested directory"
popd

popd
rm -rf $probe

# --- conf.d guard chain -----------------------------------------------------
# Reproduces conf.d/phpenv.fish's decision verbatim: with no project version
# file anywhere, every guard must pass so the global version can initialize
# PATH. Before the fix all four blocked and the init line was dead code.
set -l clean (mktemp -d 2>/dev/null; or mktemp -d -t phpenv-clean)
pushd $clean
set -l blocked 0
for f in .php-version .tool-version .tool-versions composer.json
    if not __phpenv_find_version_file $f >/dev/null 2>&1
        # guard passes, as it must
    else
        set blocked (math $blocked + 1)
    end
end
assert_eq $blocked 0 "conf.d guard chain: no guard blocks when no version file exists"
popd
rm -rf $clean

# --- __phpenv_restore_system_path -------------------------------------------
# No stored PATH: must report failure rather than claiming a restore.
set -e PHPENV_ORIGINAL_PATH
__phpenv_restore_system_path >/dev/null 2>&1
assert_fails $status "restore_system_path: fails when no original PATH is stored"

# `use system` must propagate that failure, not print "Restored system PHP".
set -e PHPENV_ORIGINAL_PATH
set -l out (__phpenv_use system 2>&1)
assert_fails $status "use system: fails when there is nothing to restore"
if string match -q "*Restored system PHP*" "$out"
    echo "FAIL use system: claimed success with nothing to restore: '$out'"
    set -g test_failures (math $test_failures + 1)
else
    echo "ok   use system: does not claim success with nothing to restore"
end

# Round trip: a stored PATH must come back exactly, and the tracking
# variables must be cleared so a later switch re-stores a fresh baseline.
set -l original $PATH
set -g PHPENV_ORIGINAL_PATH $PATH
set -g PHPENV_CURRENT_VERSION 8.3
set -g PHPENV_CURRENT_PATH /nonexistent/bin
set -gx PATH /nonexistent/bin $PATH

__phpenv_restore_system_path >/dev/null
assert_status $status 0 "restore_system_path: succeeds when an original PATH is stored"
assert_eq (string join : $PATH) (string join : $original) \
    "restore_system_path: PATH round-trips exactly"

if set -q PHPENV_CURRENT_VERSION; or set -q PHPENV_CURRENT_PATH; or set -q PHPENV_ORIGINAL_PATH
    echo "FAIL restore_system_path: left tracking variables set"
    set -g test_failures (math $test_failures + 1)
else
    echo "ok   restore_system_path: clears the tracking variables"
end

# --- __phpenv_set_php_path failure paths ------------------------------------
# A version with no installation must fail loudly and must not touch PATH.
set -l before (string join : $PATH)
__phpenv_set_php_path 99.99 >/dev/null 2>&1
assert_fails $status "set_php_path: fails for a version that is not installed"
assert_eq (string join : $PATH) $before "set_php_path: leaves PATH untouched on failure"

# A lookup that fails must not mutate the filesystem: the apt provider used to
# mkdir the shim directory before checking the version existed.
if test -d "$xdg_sandbox/phpenv/shims"
    echo "FAIL set_php_path: failed lookup created the shim directory"
    set -g test_failures (math $test_failures + 1)
else
    echo "ok   set_php_path: failed lookup leaves no shim directory"
end

# --- PHPENV_PROVIDER override validation ------------------------------------
# The override must be rejected when the provider's backing tool is absent,
# not just when the name is misspelled. Only the branch whose tool is missing
# on this machine can be asserted, so pick it at runtime rather than assuming.
set -l saved_provider
if set -q PHPENV_PROVIDER
    set saved_provider $PHPENV_PROVIDER
end

set -gx PHPENV_PROVIDER nonsense
set -l bogus (__phpenv_get_provider 2>/dev/null)
if contains -- "$bogus" homebrew apt
    echo "ok   provider override: a misspelled name falls back to auto-detect ($bogus)"
else
    echo "FAIL provider override: misspelled name yielded '$bogus'"
    set -g test_failures (math $test_failures + 1)
end

if not command -q brew
    set -gx PHPENV_PROVIDER homebrew
    set -l warned (__phpenv_get_provider 2>&1 >/dev/null)
    set -l resolved (__phpenv_get_provider 2>/dev/null)
    if string match -q "*brew is not installed*" "$warned"
        echo "ok   provider override: homebrew rejected when brew is absent"
    else
        echo "FAIL provider override: no warning for homebrew without brew: '$warned'"
        set -g test_failures (math $test_failures + 1)
    end
    if test "$resolved" = homebrew; and not command -q brew
        echo "FAIL provider override: returned homebrew despite brew being absent"
        set -g test_failures (math $test_failures + 1)
    else
        echo "ok   provider override: falls back rather than returning an unusable provider"
    end
else if not command -q apt-get
    set -gx PHPENV_PROVIDER apt
    set -l warned (__phpenv_get_provider 2>&1 >/dev/null)
    if string match -q "*apt-get is not installed*" "$warned"
        echo "ok   provider override: apt rejected when apt-get is absent"
    else
        echo "FAIL provider override: no warning for apt without apt-get: '$warned'"
        set -g test_failures (math $test_failures + 1)
    end
else
    echo "ok   provider override: both brew and apt-get present, unusable-override path N/A here"
end

set -e PHPENV_PROVIDER
if test -n "$saved_provider"
    set -gx PHPENV_PROVIDER $saved_provider
end

# --- jq gate ----------------------------------------------------------------
# doctor and help must reach their own logic instead of being refused by the
# dispatcher's jq guard, and must report jq's state themselves.
#
# Ceiling: these run with jq present, so they prove the two commands are not
# gated, not that they behave correctly when jq is missing. Simulating a
# missing jq is not portable here — fish's `command` is a parser decorator
# that a function cannot shadow, and dropping jq's directory from PATH also
# drops the coreutils doctor calls (jq shares /usr/bin on CI runners). The
# reachability of doctor's `✗ jq is not installed` branch is covered by
# review, not by this suite.
set -l doctor_out (phpenv doctor 2>&1)
assert_status $status 0 "doctor: runs without being refused by the jq guard"
if string match -q "*jq is*installed*" "$doctor_out"
    echo "ok   doctor: reports jq's state rather than aborting on it"
else
    echo "FAIL doctor: no jq status line in output: '$doctor_out'"
    set -g test_failures (math $test_failures + 1)
end

phpenv help >/dev/null 2>&1
assert_status $status 0 "help: runs without being refused by the jq guard"

# ---------------------------------------------------------------------------
set -e XDG_DATA_HOME
rm -rf $xdg_sandbox

# ---------------------------------------------------------------------------
if test $test_failures -gt 0
    echo "$test_failures test(s) failed"
    exit 1
end
echo "All tests passed"
