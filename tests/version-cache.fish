#!/usr/bin/env fish
# Version-data fetch: bounded curl call and failure caching.
# Run: fish tests/version-cache.fish
#
# The fetch runs from the PWD hook, so an unbounded or uncached failing curl
# freezes the prompt on every cd. curl is replaced by a stub on PATH: no
# network is touched, and the stub logs each call's arguments so the suite
# can count fetches.

set -l repo_root (dirname (status dirname))
source $repo_root/tests/helpers.fish
source $repo_root/functions/phpenv.fish

# Keep the PWD event handler quiet
set -g PHPENV_AUTO_SWITCH false
set -g test_failures 0

set -l stub_dir (mktemp -d)
set -gx STUB_CURL_LOG $stub_dir/calls
set -gx STUB_CURL_MODE fail
# Fails like a timed-out curl (exit 28, no output) unless told to succeed.
# "partial" times out mid-body: output written, then exit 28.
printf '%s\n' '#!/bin/sh' \
    'echo "$*" >>"$STUB_CURL_LOG"' \
    '[ "$STUB_CURL_MODE" = ok ] && echo "{\"8.x\": \"8.4\"}" && exit 0' \
    '[ "$STUB_CURL_MODE" = partial ] && echo "{\"8.x\": \"8" && exit 28' \
    'exit 28' >$stub_dir/curl
chmod +x $stub_dir/curl
set -gx PATH $stub_dir $PATH

# Number of times the stub curl has run so far.
function stub_calls
    if test -f $STUB_CURL_LOG
        count (cat $STUB_CURL_LOG)
    else
        echo 0
    end
end

# --- failed fetch ----------------------------------------------------------
set -l out (__phpenv_get_version_info)
assert_eq "$out" "" "failed fetch prints nothing"
assert_eq (stub_calls) 1 "failed fetch calls curl once"
set -l args (cat $STUB_CURL_LOG)
if string match -q -- '*--connect-timeout 2*' $args[1]; and string match -q -- '*--max-time 4*' $args[1]
    echo "ok   curl is bounded by --connect-timeout and --max-time"
else
    echo "FAIL curl is not bounded: args '$args[1]'"
    set -g test_failures (math $test_failures + 1)
end

set out (__phpenv_get_version_info)
assert_eq "$out" "" "cached failure prints nothing"
assert_eq (stub_calls) 1 "cached failure does not refetch"

assert_eq (__phpenv_parse_version_field 8.x 8.4) 8.4 "cached failure falls back"
assert_eq (stub_calls) 1 "fallback does not refetch"

# --- expired failure, successful refetch ----------------------------------
set -gx STUB_CURL_MODE ok
set -g __phpenv_version_cache_time (math (date +%s) - 301)
set out (__phpenv_get_version_info)
assert_eq "$out" '{"8.x": "8.4"}' "expired failure refetches"
assert_eq (stub_calls) 2 "expired failure calls curl again"

set out (__phpenv_get_version_info)
assert_eq "$out" '{"8.x": "8.4"}' "cached success is returned"
assert_eq (stub_calls) 2 "cached success does not refetch"

# --- partial transfer ------------------------------------------------------
set -gx STUB_CURL_MODE partial
set -g __phpenv_version_cache_time (math (date +%s) - 301)
set out (__phpenv_get_version_info)
assert_eq "$out" "" "partial transfer prints nothing"
assert_eq "$__phpenv_version_cache" unavailable "partial transfer is cached as a failure"

rm -rf $stub_dir

# ---------------------------------------------------------------------------
if test $test_failures -gt 0
    echo "$test_failures test(s) failed"
    exit 1
end
echo "All tests passed"
