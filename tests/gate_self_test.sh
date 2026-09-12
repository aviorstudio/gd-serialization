#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RUNNER="$SCRIPT_DIR/test.sh"
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

expect_pass success env RUNNER_FIXTURE_MODE=success "$RUNNER" "$FIXTURE"
expect_fail push_error_zero env RUNNER_FIXTURE_MODE=push_error_zero "$RUNNER" "$FIXTURE"
expect_fail assertion_overwritten env RUNNER_FIXTURE_MODE=assert_overwritten "$RUNNER" "$FIXTURE"
expect_fail parse_unreachable "$RUNNER" "$SCRIPT_DIR/fixtures/parse_failure_fixture.gd"
expect_fail timeout env TEST_TIMEOUT_SECONDS=1 RUNNER_FIXTURE_MODE=timeout "$RUNNER" "$FIXTURE"
expect_fail missing_script "$RUNNER" "$SCRIPT_DIR/fixtures/does_not_exist.gd"
expect_pass restored_success env RUNNER_FIXTURE_MODE=success "$RUNNER" "$FIXTURE"
