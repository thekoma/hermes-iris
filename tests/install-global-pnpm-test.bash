#!/bin/bash
set -u

source "$(dirname "$0")/helpers/test-helper.bash"

test_requires_pnpm_home() {
    local output status
    set +e
    output=$(/bin/bash "$REPO_ROOT/scripts/install-global-pnpm.sh" 2>&1)
    status=$?
    set -e

    assert_status 1 "$status"
    assert_contains "$output" "PNPM_HOME is required"
}

test_uses_corepack_when_available() {
    new_sandbox
    fake_commands corepack node pnpm
    local pnpm_home="$TEST_TMP/pnpm"

    PATH="$FAKE_BIN:/usr/bin:/bin" \
        PNPM_HOME="$pnpm_home" \
        /bin/bash "$REPO_ROOT/scripts/install-global-pnpm.sh"

    assert_file_contains "$COMMAND_LOG" "corepack <enable> <pnpm>"
    assert_file_contains "$COMMAND_LOG" "corepack <prepare> <pnpm@latest> <--activate>"
    assert_file_contains "$COMMAND_LOG" "pnpm <add> <-g> <mcporter> <@agentmemory/mcp>"
    assert_not_contains "$(cat "$COMMAND_LOG")" "npm <install>"
}

test_installs_pnpm_when_corepack_is_unavailable() {
    new_sandbox
    fake_commands node npm pnpm
    local pnpm_home="$TEST_TMP/pnpm"
    local system_command
    for system_command in find ln mkdir rm; do
        ln -s "$(command -v "$system_command")" "$FAKE_BIN/$system_command"
    done

    PATH="$FAKE_BIN" \
        PNPM_HOME="$pnpm_home" \
        /bin/bash "$REPO_ROOT/scripts/install-global-pnpm.sh"

    assert_file_contains "$COMMAND_LOG" "npm <install> <-g> <pnpm@latest>"
    assert_file_contains "$COMMAND_LOG" "pnpm <add> <-g> <mcporter> <@agentmemory/mcp>"
}

run_test "requires PNPM_HOME" test_requires_pnpm_home
run_test "bootstraps pnpm with corepack when present" test_uses_corepack_when_available
run_test "falls back to npm when corepack is absent" test_installs_pnpm_when_corepack_is_unavailable
finish_tests
