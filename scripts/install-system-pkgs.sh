#!/usr/bin/env bash
# Install runtime system packages on top of the upstream hermes-agent image.
# Edit this list to add/remove tools — changes invalidate only this Docker
# layer. Upstream already provides: ffmpeg, git, ripgrep, procps, curl,
# ca-certs, openssh-client, docker-cli, python3 + uv, node 22 + npm.
set -euo pipefail

PACKAGES=(
    gh
    iproute2
    jq
    lsof
    mosh
    ncdu
    sqlite3
    tmux
    vim
    wget
    yq
)

apt-get update
apt-get install -yq --no-install-recommends "${PACKAGES[@]}"
rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
