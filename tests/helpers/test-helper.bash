#!/bin/bash

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TEST_COUNT=0
FAILURE_COUNT=0

run_test() {
    local name=$1
    local test_function=$2
    local status
    TEST_COUNT=$((TEST_COUNT + 1))

    set +e
    (set -e; "$test_function")
    status=$?
    set -e

    if ((status == 0)); then
        printf 'ok %d - %s\n' "$TEST_COUNT" "$name"
    else
        printf 'not ok %d - %s\n' "$TEST_COUNT" "$name"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
}

finish_tests() {
    printf '1..%d\n' "$TEST_COUNT"
    ((FAILURE_COUNT == 0))
}

new_sandbox() {
    TEST_TMP=$(mktemp -d)
    FAKE_BIN="$TEST_TMP/bin"
    COMMAND_LOG="$TEST_TMP/commands.log"
    mkdir -p "$FAKE_BIN"
    : >"$COMMAND_LOG"
    export COMMAND_LOG
    trap 'rm -rf "$TEST_TMP"' EXIT
}

fake_commands() {
    local command_name
    for command_name in "$@"; do
        ln -s "$REPO_ROOT/tests/helpers/fake-command" "$FAKE_BIN/$command_name"
    done
}

assert_status() {
    local expected=$1
    local actual=$2
    [[ $actual -eq $expected ]] || {
        printf 'expected status %s, got %s\n' "$expected" "$actual" >&2
        return 1
    }
}

assert_contains() {
    local value=$1
    local expected=$2
    [[ $value == *"$expected"* ]] || {
        printf 'expected value to contain: %s\nactual: %s\n' "$expected" "$value" >&2
        return 1
    }
}

assert_not_contains() {
    local value=$1
    local unexpected=$2
    [[ $value != *"$unexpected"* ]] || {
        printf 'expected value not to contain: %s\nactual: %s\n' "$unexpected" "$value" >&2
        return 1
    }
}

assert_file_contains() {
    local file=$1
    local expected=$2
    local value
    value=$(cat "$file")
    assert_contains "$value" "$expected"
}
