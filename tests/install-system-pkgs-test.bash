#!/bin/bash
set -u

source "$(dirname "$0")/helpers/test-helper.bash"

test_installs_runtime_packages_and_cleans_apt_state() {
    new_sandbox
    fake_commands apt-get rm

    PATH="$FAKE_BIN:/usr/bin:/bin" \
        /bin/bash "$REPO_ROOT/scripts/install-system-pkgs.sh"

    local commands
    commands=$(cat "$COMMAND_LOG")
    assert_contains "$commands" "apt-get <update>"
    assert_contains "$commands" "apt-get <install> <-yq> <--no-install-recommends> <gh> <iproute2> <jq> <lsof> <mosh> <ncdu> <sqlite3> <tmux> <vim> <wget> <yq>"
    assert_contains "$commands" "rm <-rf> </var/cache/apt/archives> </var/lib/apt/lists/"
}

run_test "installs the runtime package set and clears apt state" test_installs_runtime_packages_and_cleans_apt_state
finish_tests
