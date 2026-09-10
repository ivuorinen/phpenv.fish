# Shared assertions for the phpenv test suites.
#
# No shebang and not executable, unlike the suites themselves: this file is
# sourced, never run. That is also why the CI test step and the documented
# test command skip it when globbing tests/*.fish.
#
# Each suite sets `test_failures` to 0 before
# sourcing; assertions bump it in global scope so the suite's final exit
# check sees the count. Kept in one file because three suites had otherwise
# grown three byte-identical copies of assert_eq, free to drift apart.

# Compare two values, printing a TAP-ish ok/FAIL line and counting failures.
function assert_eq -a actual expected label
    if test "$actual" = "$expected"
        echo "ok   $label"
    else
        echo "FAIL $label: expected '$expected', got '$actual'"
        set -g test_failures (math $test_failures + 1)
    end
end

# Assert a command's recorded exit status. Callers pass $status explicitly
# because any command run between the subject and the assertion — including
# the assertion call itself — overwrites it.
function assert_status -a actual expected label
    assert_eq "$actual" "$expected" $label
end

# Assert the inverse: the subject was expected to fail.
function assert_fails -a actual label
    if test "$actual" -ne 0
        echo "ok   $label"
    else
        echo "FAIL $label: expected a non-zero status, got 0"
        set -g test_failures (math $test_failures + 1)
    end
end
