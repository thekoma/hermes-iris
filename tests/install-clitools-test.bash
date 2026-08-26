#!/bin/bash
set -u

source "$(dirname "$0")/helpers/test-helper.bash"

test_requires_versions() {
    local output status
    set +e
    output=$(/bin/bash "$REPO_ROOT/scripts/install-clitools.sh" 2>&1)
    status=$?
    set -e

    assert_status 1 "$status"
    assert_contains "$output" "ARGOCD_VERSION is required"
}

test_downloads_expected_archives() {
    new_sandbox
    fake_commands bash curl strip tar
    local output_dir="$TEST_TMP/out"
    local home_dir="$TEST_TMP/home"
    mkdir -p "$home_dir"

    PATH="$FAKE_BIN:/usr/bin:/bin" \
        HOME="$home_dir" \
        OUT_DIR="$output_dir" \
        ARGOCD_VERSION=v3.4.3 \
        HELM_VERSION=v4.2.0 \
        KUBECTL_VERSION=v1.35.1 \
        CLAUDE_CODE_VERSION=v2.1.173 \
        ARCH=arm64 \
        /bin/bash "$REPO_ROOT/scripts/install-clitools.sh"

    [[ -x "$output_dir/argocd" ]]
    [[ -x "$output_dir/helm" ]]
    [[ -x "$output_dir/kubectl" ]]
    [[ -x "$output_dir/claude" ]]
    assert_file_contains "$COMMAND_LOG" "argocd-linux-arm64"
    assert_file_contains "$COMMAND_LOG" "helm-v4.2.0-linux-arm64.tar.gz"
    assert_file_contains "$COMMAND_LOG" "/v1.35.1/bin/linux/arm64/kubectl"
    assert_file_contains "$COMMAND_LOG" "bash <-s> <--> <2.1.173>"
    assert_file_contains "$COMMAND_LOG" "strip <$output_dir/argocd> <$output_dir/helm> <$output_dir/kubectl>"
}

run_test "requires pinned tool versions" test_requires_versions
run_test "downloads and prepares the requested architecture" test_downloads_expected_archives
finish_tests
