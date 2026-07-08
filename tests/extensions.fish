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

if test $test_failures -gt 0
    echo "$test_failures test(s) failed"
    exit 1
end
echo "All tests passed"
