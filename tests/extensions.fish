#!/usr/bin/env fish
# Multi-extension install/uninstall checks (providers stubbed).
# Run: fish tests/extensions.fish

set -l repo_root (dirname (status dirname))
source $repo_root/functions/phpenv.fish

# Keep the PWD event handler quiet while the test runs
set -g PHPENV_AUTO_SWITCH false
set -g test_failures 0

function assert_eq -a actual expected label
    if test "$actual" = "$expected"
        echo "ok   $label"
    else
        echo "FAIL $label: expected '$expected', got '$actual'"
        set -g test_failures (math $test_failures + 1)
    end
end

# --- provider stubs: record calls, fail on 'badext' -------------------------
function __phpenv_get_provider
    echo apt
end
function __phpenv_detect_version
    echo 8.3
end
set -g stub_installed
function __phpenv_provider_apt_ext_install -a ext ver
    set -a stub_installed "$ext@$ver"
    test "$ext" != badext
end
function __phpenv_provider_apt_ext_uninstall -a ext ver
    test "$ext" != badext
end

# --- install: multiple extensions in one call -------------------------------
set stub_installed
phpenv ext install ext1 ext2 ext3 >/dev/null
assert_eq $status 0 "multi-install exits 0"
assert_eq "$stub_installed" "ext1@8.3 ext2@8.3 ext3@8.3" "multi-install installs all three"

# --- install: one failure -> nonzero, remaining still attempted -------------
set stub_installed
set -l out (phpenv ext install ext1 badext ext2)
assert_eq $status 1 "partial failure exits 1"
assert_eq "$stub_installed" "ext1@8.3 badext@8.3 ext2@8.3" "failure does not stop the loop"
if string match -q "*Failed to install: badext*" "$out"
    echo "ok   failure summary names badext"
else
    echo "FAIL failure summary: got '$out'"
    set -g test_failures (math $test_failures + 1)
end

# --- install: no args -> usage error ----------------------------------------
phpenv ext install >/dev/null
assert_eq $status 1 "install with no args exits 1"

# --- install: single extension still works (default-extensions path) --------
set stub_installed
phpenv ext install ext1 >/dev/null
assert_eq $status 0 "single install exits 0"
assert_eq "$stub_installed" "ext1@8.3" "single install installs one"

# --- uninstall: multiple, with and without failure ---------------------------
phpenv ext uninstall ext1 ext2 >/dev/null
assert_eq $status 0 "multi-uninstall exits 0"
phpenv ext uninstall ext1 badext >/dev/null
assert_eq $status 1 "multi-uninstall with failure exits 1"

# --- laravel preset -----------------------------------------------------------
set stub_installed
phpenv ext install laravel >/dev/null
assert_eq $status 0 "laravel preset exits 0"
assert_eq (count $stub_installed) (count $__phpenv_preset_laravel) "laravel preset installs full set"
if contains -- "redis@8.3" $stub_installed; and contains -- "xdebug@8.3" $stub_installed
    echo "ok   laravel preset includes redis and xdebug"
else
    echo "FAIL laravel preset missing expected extensions: $stub_installed"
    set -g test_failures (math $test_failures + 1)
end
if contains -- "cli@8.3" $stub_installed; or contains -- "dev@8.3" $stub_installed
    echo "FAIL laravel preset contains non-extension packages"
    set -g test_failures (math $test_failures + 1)
else
    echo "ok   laravel preset excludes cli/dev packages"
end

# --- preset + explicit extension dedupes ---------------------------------------
set stub_installed
phpenv ext install laravel redis >/dev/null
assert_eq (count $stub_installed) (count $__phpenv_preset_laravel) "laravel + redis dedupes"

# --- from-composer -------------------------------------------------------------
set -l sandbox (mktemp -d)
echo '{
  "require": {
    "php": "^8.2",
    "ext-json": "*",
    "ext-redis": "*",
    "ext-mysqli": "*",
    "ext-dom": "*",
    "ext-simplexml": "*"
  },
  "require-dev": {
    "ext-pcov": "*"
  }
}' >$sandbox/composer.json

pushd $sandbox
set stub_installed
phpenv ext install from-composer >/dev/null
assert_eq $status 0 "from-composer exits 0"
assert_eq "$stub_installed" "xml@8.3 mysql@8.3 pcov@8.3 redis@8.3" \
    "from-composer maps aliases, skips built-ins, dedupes"
popd

# --- from-composer without composer.json ---------------------------------------
set -l empty_sandbox (mktemp -d)
pushd $empty_sandbox
set -l err (phpenv ext install from-composer 2>&1 >/dev/null)
assert_eq $status 1 "from-composer without composer.json exits 1"
assert_eq "$err" "No composer.json found" "missing composer.json reported on stderr"
popd

# --- from-composer with malformed composer.json ---------------------------------
set -l broken_sandbox (mktemp -d)
echo 'not json{' >$broken_sandbox/composer.json
pushd $broken_sandbox
set -l err (phpenv ext install from-composer 2>&1 >/dev/null)
assert_eq $status 1 "from-composer with malformed composer.json exits 1"
if string match -q "Failed to parse *" "$err"
    echo "ok   parse failure reported on stderr"
else
    echo "FAIL parse failure message: got '$err'"
    set -g test_failures (math $test_failures + 1)
end
popd
rm -rf $sandbox $empty_sandbox $broken_sandbox

if test $test_failures -gt 0
    echo "$test_failures test(s) failed"
    exit 1
end
echo "All tests passed"
