#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
GODOT="${GODOT_BIN:-godot}"
TIMEOUT_SECONDS="${TEST_TIMEOUT_SECONDS:-60}"
FAILURES=0

if (($#)); then
    TESTS=("$@")
else
    shopt -s nullglob
    TESTS=("$SCRIPT_DIR"/*_test.gd)
fi

if ((${#TESTS[@]} == 0)); then
    echo "ERROR: no Godot test scripts found" >&2
    exit 1
fi

for test in "${TESTS[@]}"; do
    if [[ ! -f "$test" ]]; then
        echo "ERROR: missing test script: $test" >&2
        FAILURES=$((FAILURES + 1))
        continue
    fi

    echo "Running $(basename "$test")..."
    log=$(mktemp)
    timeout --foreground "${TIMEOUT_SECONDS}s" "$GODOT" --headless --path "$ROOT_DIR" --script "$test" >"$log" 2>&1
    status=$?
    tee <"$log"

    if [[ $status -eq 124 ]]; then
        echo "ERROR: test timed out after ${TIMEOUT_SECONDS}s: $test" >&2
        FAILURES=$((FAILURES + 1))
    elif [[ $status -ne 0 ]]; then
        echo "ERROR: test exited with status $status: $test" >&2
        FAILURES=$((FAILURES + 1))
    fi
    if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$log"; then
        echo "ERROR: unexpected Godot error output: $test" >&2
        FAILURES=$((FAILURES + 1))
    fi
    if ! grep -Eq '^TEST_ASSERTIONS_REACHED:[1-9][0-9]*$' "$log"; then
        echo "ERROR: assertion reach sentinel missing: $test" >&2
        FAILURES=$((FAILURES + 1))
    fi
    if ! grep -q '^TEST_FAILURES:0$' "$log"; then
        echo "ERROR: assertion failure sentinel missing or nonzero: $test" >&2
        FAILURES=$((FAILURES + 1))
    fi
    rm -f "$log"
done

exit "$FAILURES"
