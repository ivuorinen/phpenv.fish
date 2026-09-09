#!/usr/bin/env fish
# Version detection / MAJOR.MINOR normalization checks.
# Run: fish tests/version-detection.fish

set -l repo_root (dirname (status dirname))
source $repo_root/tests/helpers.fish
source $repo_root/functions/phpenv.fish

# Keep the PWD event handler quiet while the test cds around
set -g PHPENV_AUTO_SWITCH false
set -g test_failures 0

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

# Bare 8.x/7.x constraints resolve via the '8.*'/'7.*' glob cases
set -l bare8 (__phpenv_parse_semver_constraint '8.x')
if string match -rq '^8\.[0-9]+$' $bare8
    echo "ok   constraint 8.x -> 8.MINOR ($bare8)"
else
    echo "FAIL constraint 8.x: got '$bare8', not 8.MINOR"
    set -g test_failures (math $test_failures + 1)
end
assert_eq (__phpenv_parse_semver_constraint '7.x') 7.4 "constraint 7.x -> 7.4"

# MINOR-pinning wildcards must not fall into the '8.*'/'7.*' latest globs
assert_eq (__phpenv_parse_semver_constraint '8.1.*') 8.1 "constraint 8.1.* -> 8.1"
assert_eq (__phpenv_parse_semver_constraint '8.1.x') 8.1 "constraint 8.1.x -> 8.1"
assert_eq (__phpenv_parse_semver_constraint '8.0.*') 8.0 "constraint 8.0.* -> 8.0"
assert_eq (__phpenv_parse_semver_constraint '7.1.*') 7.1 "constraint 7.1.* -> 7.1"

# A MINOR pin still counts when it is not the whole constraint
assert_eq (__phpenv_parse_semver_constraint '8.1.* || 8.2.*') 8.1 "compound pin -> first pin"
assert_eq (__phpenv_parse_semver_constraint '8.1.*@dev') 8.1 "stability suffix -> 8.1"
assert_eq (__phpenv_parse_semver_constraint '8.1.X') 8.1 "uppercase X wildcard -> 8.1"
assert_eq (__phpenv_parse_semver_constraint '~8.1.*') 8.1 "tilde with pin -> 8.1"
# ...but a bare major wildcard still means "latest in the series"
set -l bare_major (__phpenv_parse_semver_constraint '8.*')
if string match -rq '^8\.[0-9]+$' $bare_major
    echo "ok   constraint 8.* -> series latest ($bare_major)"
else
    echo "FAIL constraint 8.*: got '$bare_major', not 8.MINOR"
    set -g test_failures (math $test_failures + 1)
end

# __phpenv_find_version_file must signal not-found through its exit status:
# conf.d branches on the status alone to decide whether to initialize PATH
set -l probe_dir (mktemp -d 2>/dev/null; or mktemp -d -t phpenv-probe)
pushd $probe_dir
__phpenv_find_version_file .php-version >/dev/null
if test $status -eq 0
    echo "FAIL find_version_file: returned 0 with no version file present"
    set -g test_failures (math $test_failures + 1)
else
    echo "ok   find_version_file signals not-found via exit status"
end
echo 8.2 > .php-version
__phpenv_find_version_file .php-version >/dev/null
assert_eq $status 0 "find_version_file returns 0 when the file exists"
popd
rm -rf $probe_dir

# jq bracket-notation regression: "8.x" is not valid jq path syntax
set -l field_8x (__phpenv_parse_version_field "8.x" "8.4")
if string match -rq '^[0-9]+\.[0-9]+$' $field_8x
    echo "ok   version field 8.x -> MAJOR.MINOR ($field_8x)"
else
    echo "FAIL version field 8.x: got '$field_8x', not MAJOR.MINOR"
    set -g test_failures (math $test_failures + 1)
end

# --- composer.json and version files, end to end ---------------------------
# -t fallback covers BSD/macOS mktemp variants that require a template
set -l tmpdir (mktemp -d 2>/dev/null; or mktemp -d -t phpenv-test)
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

# composer.json that jq cannot parse must fall through, not abort detection
echo 'not json{' >composer.json
rm -f .php-version .tool-version .tool-versions
set -g PHPENV_GLOBAL_VERSION 8.2
assert_eq (__phpenv_detect_version) 8.2 "malformed composer.json falls through to the global version"
set -e PHPENV_GLOBAL_VERSION

# composer.json with no php key at all: same fall-through, different cause
echo '{"require":{"monolog/monolog":"^3.0"}}' >composer.json
set -g PHPENV_GLOBAL_VERSION 8.2
assert_eq (__phpenv_detect_version) 8.2 "composer.json without a php key falls through"
set -e PHPENV_GLOBAL_VERSION
rm -f composer.json

# --- config set default-extensions rejects invalid input -------------------
set -g PHPENV_DEFAULT_EXTENSIONS opcache
__phpenv_config_set default-extensions 'foo;bar rm' >/dev/null 2>&1
assert_fails $status "config set default-extensions: rejects an invalid list"
assert_eq "$PHPENV_DEFAULT_EXTENSIONS" opcache \
    "config set default-extensions: leaves the previous value when rejecting"
__phpenv_config_set default-extensions 'opcache xdebug redis' >/dev/null
assert_status $status 0 "config set default-extensions: accepts a valid list"
assert_eq "$PHPENV_DEFAULT_EXTENSIONS" "opcache xdebug redis" \
    "config set default-extensions: stores a valid list"

# Surrounding whitespace is a typo, not a syntax error: trim, do not reject
__phpenv_config_set default-extensions '  opcache xdebug  ' >/dev/null
assert_status $status 0 "config set default-extensions: trims surrounding whitespace"
assert_eq "$PHPENV_DEFAULT_EXTENSIONS" "opcache xdebug" \
    "config set default-extensions: stores the trimmed value"

# A wrong separator is still a real error
set -g PHPENV_DEFAULT_EXTENSIONS keep
__phpenv_config_set default-extensions 'opcache,xdebug' >/dev/null 2>&1
assert_fails $status "config set default-extensions: still rejects comma separators"
assert_eq "$PHPENV_DEFAULT_EXTENSIONS" keep \
    "config set default-extensions: comma rejection leaves the value alone"
set -e PHPENV_DEFAULT_EXTENSIONS

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
