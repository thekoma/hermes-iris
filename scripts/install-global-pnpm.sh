#!/usr/bin/env bash
# Install pnpm global packages into $PNPM_HOME/bin (see Dockerfile).
# Edit this list to add/remove tools — changes invalidate only this layer.
set -euo pipefail

: "${PNPM_HOME:?PNPM_HOME is required}"

PACKAGES=(
    mcporter
)

# Packages whose postinstall scripts MUST run.  pnpm 10+ refuses lifecycle
# scripts unless explicitly allowed.  Add entries here only if a baseline
# package above ships native bindings that fail without postinstall.
ALLOW_BUILDS=()

ALLOW_BUILD_ARGS=()
for pkg in "${ALLOW_BUILDS[@]}"; do
    ALLOW_BUILD_ARGS+=("--allow-build=$pkg")
done

# Bootstrap pnpm via corepack (already shipped with upstream node 22 LTS).
corepack enable pnpm
corepack prepare pnpm@latest --activate

mkdir -p "$PNPM_HOME/bin"
pnpm add -g "${ALLOW_BUILD_ARGS[@]}" "${PACKAGES[@]}"
