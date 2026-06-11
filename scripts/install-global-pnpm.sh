#!/usr/bin/env bash
# Install pnpm global packages into $PNPM_HOME/bin (see Dockerfile).
# Edit this list to add/remove tools — changes invalidate only this layer.
set -euo pipefail

: "${PNPM_HOME:?PNPM_HOME is required}"

PACKAGES=(
    mcporter
    "@anthropic-ai/claude-code"
    # MCP bridge to the production agentmemory instance (AGENTMEMORY_URL);
    # the server itself runs elsewhere, so no @agentmemory/agentmemory here.
    "@agentmemory/mcp"
)

# Packages whose postinstall scripts MUST run.  pnpm 10+ refuses lifecycle
# scripts unless explicitly allowed.  Add entries here only if a baseline
# package above ships native bindings that fail without postinstall.
ALLOW_BUILDS=(
    # postinstall downloads the platform-native claude binary; without it
    # the CLI exits with "claude native binary not installed".
    "@anthropic-ai/claude-code"
)

ALLOW_BUILD_ARGS=()
for pkg in "${ALLOW_BUILDS[@]}"; do
    ALLOW_BUILD_ARGS+=("--allow-build=$pkg")
done

# Bootstrap pnpm via corepack (already shipped with upstream node 22 LTS).
corepack enable pnpm
corepack prepare pnpm@latest --activate

mkdir -p "$PNPM_HOME/bin"
pnpm add -g "${ALLOW_BUILD_ARGS[@]}" "${PACKAGES[@]}"
