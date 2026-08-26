#!/bin/bash
set -u

source "$(dirname "$0")/helpers/test-helper.bash"

test_exits_when_source_is_missing() {
    new_sandbox
    local hermes_home="$TEST_TMP/hermes"
    mkdir -p "$hermes_home"

    HERMES_HOME="$hermes_home" \
        AGENTMEMORY_PLUGIN_SOURCE="$TEST_TMP/missing" \
        /bin/sh "$REPO_ROOT/scripts/cont-init.d/03-agentmemory-plugin"

    [[ ! -e "$hermes_home/plugins/agentmemory" ]]
}

test_exits_when_hermes_home_is_missing() {
    new_sandbox
    local source_dir="$TEST_TMP/source"
    mkdir -p "$source_dir"
    printf 'plugin\n' >"$source_dir/plugin.py"

    AGENTMEMORY_PLUGIN_SOURCE="$source_dir" \
        /bin/sh "$REPO_ROOT/scripts/cont-init.d/03-agentmemory-plugin"
}

test_syncs_plugin_and_repairs_ownership() {
    new_sandbox
    fake_commands chown
    local source_dir="$TEST_TMP/source"
    local hermes_home="$TEST_TMP/hermes home"
    mkdir -p "$source_dir/subdir" "$hermes_home/plugins/agentmemory"
    printf 'new plugin\n' >"$source_dir/plugin.py"
    printf 'nested\n' >"$source_dir/subdir/data.txt"
    printf 'old plugin\n' >"$hermes_home/plugins/agentmemory/plugin.py"

    PATH="$FAKE_BIN:/usr/bin:/bin" \
        HERMES_HOME="$hermes_home" \
        AGENTMEMORY_PLUGIN_SOURCE="$source_dir" \
        /bin/sh "$REPO_ROOT/scripts/cont-init.d/03-agentmemory-plugin"

    [[ $(cat "$hermes_home/plugins/agentmemory/plugin.py") == "new plugin" ]]
    [[ $(cat "$hermes_home/plugins/agentmemory/subdir/data.txt") == "nested" ]]
    assert_file_contains "$COMMAND_LOG" "chown <-R> <hermes:hermes> <$hermes_home/plugins>"
}

run_test "does nothing when the baked plugin is absent" test_exits_when_source_is_missing
run_test "does nothing when HERMES_HOME is unavailable" test_exits_when_hermes_home_is_missing
run_test "syncs the plugin tree and restores ownership" test_syncs_plugin_and_repairs_ownership
finish_tests
