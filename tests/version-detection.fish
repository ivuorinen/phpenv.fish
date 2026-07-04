#!/usr/bin/env fish
# Version detection / MAJOR.MINOR normalization checks.
# Run: fish tests/version-detection.fish

set -l repo_root (dirname (status dirname))
source $repo_root/functions/phpenv.fish

# Keep the PWD event handler quiet while the test cds around
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

# --- __phpenv_normalize_version -------------------------------------------
assert_eq (__phpenv_normalize_version 8.1.12) 8.1 "normalize 8.1.12 -> 8.1"
assert_eq (__phpenv_normalize_version 8.1) 8.1 "normalize 8.1 unchanged"
assert_eq (__phpenv_normalize_version v8.2.3) 8.2 "normalize v8.2.3 -> 8.2"
assert_eq (__phpenv_normalize_version 8.1.x) 8.1 "normalize 8.1.x -> 8.1"
assert_eq (__phpenv_normalize_version 8.10.1) 8.10 "normalize 8.10.1 -> 8.10"
assert_eq (__phpenv_normalize_version latest) latest "alias latest passes through"
assert_eq (__phpenv_normalize_version 8.x) 8.x "alias 8.x passes through"

# --- __phpenv_parse_semver_constraint (static cases only) ------------------
assert_eq (__phpenv_parse_semver_constraint '~8.2.0') 8.2 "constraint ~8.2.0 -> 8.2"
assert_eq (__phpenv_parse_semver_constraint '8.1.3') 8.1 "constraint 8.1.3 -> 8.1"
assert_eq (__phpenv_parse_semver_constraint '>=8.1 <9.0') 8.1 "constraint '>=8.1 <9.0' -> 8.1"
set -l caret (__phpenv_parse_semver_constraint '^8.1')
if string match -rq '^[0-9]+\.[0-9]+$' $caret
    echo "ok   constraint ^8.1 -> MAJOR.MINOR ($caret)"
else
    echo "FAIL constraint ^8.1: got '$caret', not MAJOR.MINOR"
    set -g test_failures (math $test_failures + 1)
end

set -l gte (__phpenv_parse_semver_constraint '>=8.0')
if string match -rq '^[0-9]+\.[0-9]+$' $gte
    echo "ok   constraint >=8.0 -> MAJOR.MINOR ($gte)"
else
    echo "FAIL constraint >=8.0: got '$gte', not MAJOR.MINOR"
    set -g test_failures (math $test_failures + 1)
end

# jq bracket-notation regression: "8.x" is not valid jq path syntax
set -l field_8x (__phpenv_parse_version_field "8.x" "8.4")
if string match -rq '^[0-9]+\.[0-9]+$' $field_8x
    echo "ok   version field 8.x -> MAJOR.MINOR ($field_8x)"
else
    echo "FAIL version field 8.x: got '$field_8x', not MAJOR.MINOR"
    set -g test_failures (math $test_failures + 1)
end

# --- composer.json and version files, end to end ---------------------------
set -l tmpdir (mktemp -d)
pushd $tmpdir

echo '{"config":{"platform":{"php":"8.1.12"}}}' > composer.json
assert_eq (__phpenv_detect_version) 8.1 "composer config.platform.php 8.1.12 -> 8.1"

echo '{"require":{"php":"~8.2.0"}}' > composer.json
assert_eq (__phpenv_detect_version) 8.2 "composer require.php ~8.2.0 -> 8.2"

echo 'php 8.2.15' > .tool-versions
assert_eq (__phpenv_detect_version) 8.2 ".tool-versions 'php 8.2.15' -> 8.2"

printf 'nodejs 20.1.0\nphp\t8.3.7\n' > .tool-version
assert_eq (__phpenv_detect_version) 8.3 ".tool-version tab-separated 'php 8.3.7' -> 8.3"

echo '8.2.15' > .php-version
assert_eq (__phpenv_detect_version) 8.2 ".php-version 8.2.15 -> 8.2"

rm .php-version
__phpenv_local 8.1.12 >/dev/null
assert_eq (cat .php-version) 8.1 "phpenv local 8.1.12 writes 8.1"
rm .php-version
if __phpenv_local banana >/dev/null
    echo "FAIL phpenv local banana: accepted invalid version"
    set -g test_failures (math $test_failures + 1)
else if test -f .php-version
    echo "FAIL phpenv local banana: wrote .php-version despite rejection"
    set -g test_failures (math $test_failures + 1)
else
    echo "ok   phpenv local banana rejected"
end

# homebrew: unversioned `php` formula version read from Cellar dirname, not remote JSON
mkdir -p cellar/php/8.4.9 cellar/php/8.4.11
set -g __phpenv_cellar_cache $tmpdir/cellar
assert_eq (__phpenv_brew_unversioned_version) 8.4 "brew unversioned php (Cellar 8.4.11) -> 8.4"
if __phpenv_provider_homebrew_is_installed 8.4
    echo "ok   brew is_installed 8.4 via unversioned formula"
else
    echo "FAIL brew is_installed 8.4 via unversioned formula"
    set -g test_failures (math $test_failures + 1)
end
if __phpenv_provider_homebrew_is_installed 8.3
    echo "FAIL brew is_installed 8.3: reported installed, only 8.4 exists"
    set -g test_failures (math $test_failures + 1)
else
    echo "ok   brew is_installed 8.3 correctly false"
end
set -g __phpenv_cellar_cache ""

popd
rm -rf $tmpdir

# ---------------------------------------------------------------------------
if test $test_failures -gt 0
    echo "$test_failures test(s) failed"
    exit 1
end
echo "All tests passed"
