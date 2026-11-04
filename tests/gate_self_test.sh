#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUNNER="$TOOLS_ROOT/helpers/godot-test.py"
FIXTURE="$SCRIPT_DIR/fixtures/runner_fixture.gd"

expect_pass() {
    local name=$1
    shift
    if ! "$@"; then
        echo "Gate self-test expected PASS: $name" >&2
        exit 1
    fi
    echo "CONTROL_RESTORED_PASS:$name"
}

expect_fail() {
    local name=$1
    shift
    if "$@"; then
        echo "Gate self-test expected FAIL: $name" >&2
        exit 1
    fi
    echo "NEGATIVE_CONTROL_FAILED_AS_EXPECTED:$name"
}

expect_pass success env RUNNER_FIXTURE_MODE=success python3 "$RUNNER" --project "$SCRIPT_DIR/.." --program "$FIXTURE" --sentinel TEST_FAILURES:0 --assertions-regex '^TEST_ASSERTIONS_REACHED:([1-9][0-9]*)$'
expect_fail push_error_zero env RUNNER_FIXTURE_MODE=push_error_zero python3 "$RUNNER" --project "$SCRIPT_DIR/.." --program "$FIXTURE" --sentinel TEST_FAILURES:0 --assertions-regex '^TEST_ASSERTIONS_REACHED:([1-9][0-9]*)$'
expect_fail assertion_overwritten env RUNNER_FIXTURE_MODE=assert_overwritten python3 "$RUNNER" --project "$SCRIPT_DIR/.." --program "$FIXTURE" --sentinel TEST_FAILURES:0 --assertions-regex '^TEST_ASSERTIONS_REACHED:([1-9][0-9]*)$'
expect_fail parse_unreachable python3 "$RUNNER" --project "$SCRIPT_DIR/.." --program "$SCRIPT_DIR/fixtures/parse_failure_fixture.gd" --sentinel TEST_FAILURES:0 --assertions-regex '^TEST_ASSERTIONS_REACHED:([1-9][0-9]*)$'
expect_fail timeout env RUNNER_FIXTURE_MODE=timeout python3 "$RUNNER" --timeout 1 --project "$SCRIPT_DIR/.." --program "$FIXTURE" --sentinel TEST_FAILURES:0 --assertions-regex '^TEST_ASSERTIONS_REACHED:([1-9][0-9]*)$'
expect_fail missing_script python3 "$RUNNER" --project "$SCRIPT_DIR/.." --program "$SCRIPT_DIR/fixtures/does_not_exist.gd" --sentinel TEST_FAILURES:0 --assertions-regex '^TEST_ASSERTIONS_REACHED:([1-9][0-9]*)$'
expect_pass restored_success env RUNNER_FIXTURE_MODE=success python3 "$RUNNER" --project "$SCRIPT_DIR/.." --program "$FIXTURE" --sentinel TEST_FAILURES:0 --assertions-regex '^TEST_ASSERTIONS_REACHED:([1-9][0-9]*)$'
