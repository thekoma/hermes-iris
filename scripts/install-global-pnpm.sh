#!/usr/bin/env bash
# Install pnpm global packages into $PNPM_HOME/bin (see Dockerfile).
# Edit this list to add/remove tools — changes invalidate only this layer.
set -euo pipefail
trap 'echo "install-global-pnpm.sh: failed at line $LINENO" >&2' ERR

: "${PNPM_HOME:?PNPM_HOME is required}"

PACKAGES=(
    mcporter
    # MCP bridge to the production agentmemory instance (AGENTMEMORY_URL);
    # the server itself runs elsewhere, so no @agentmemory/agentmemory here.
    # claude-code is NOT here on purpose: its npm package ships the 236M
    # native binary four times over — the Dockerfile bakes the single
    # official binary via the clitools stage instead.
    "@agentmemory/mcp"
)

# Packages whose postinstall scripts MUST run.  pnpm 10+ refuses lifecycle
# scripts unless explicitly allowed.  Add entries here only if a baseline
# package above ships native bindings that fail without postinstall.
ALLOW_BUILDS=()

ALLOW_BUILD_ARGS=()
for pkg in "${ALLOW_BUILDS[@]}"; do
    ALLOW_BUILD_ARGS+=("--allow-build=$pkg")
done

# Bootstrap pnpm.  Upstream shipped corepack while it was on node 22, but as of
# node 26 (v26.5.1 in the base image) corepack is no longer bundled — it was
# unbundled in node 25 — so `corepack enable` exits 127 and takes the build with
# it.  Prefer it when present, otherwise install pnpm straight from npm; either
# way pnpm lands in /usr/local/bin, which is npm's global prefix here.
if command -v corepack >/dev/null 2>&1; then
    corepack enable pnpm
    corepack prepare pnpm@latest --activate
else
    npm install -g pnpm@latest
fi

mkdir -p "$PNPM_HOME/bin"
pnpm add -g "${ALLOW_BUILD_ARGS[@]}" "${PACKAGES[@]}"

# --- prune dead weight from the pnpm store ---
# @agentmemory/mcp drags in @agentmemory/agentmemory (the full server) as a
# dependency, and with it onnxruntime for every platform plus the Claude
# Agent SDK's bundled 236M claude binary.  Store payloads are hardlinked
# from links/ — every link of an inode must go for bytes to be freed.
# This intentionally breaks `pnpm add -g` integrity for the pruned
# packages at runtime, which we don't support anyway (/usr/local is
# root-owned).

# Delete every hardlink of each file read from stdin, then the file itself.
# The -samefile sweep races with its own deletions (a link can vanish while
# find walks the tree), so its exit status is tolerated — but stderr stays
# visible and failing to remove the payload itself is fatal.
prune_inodes() {
    while IFS= read -r f; do
        [ -e "$f" ] || continue
        find "$PNPM_HOME" -samefile "$f" ! -path "$f" -delete || true
        rm -f "$f" || { echo "failed to prune $f" >&2; return 1; }
    done
}

NODE_ARCH=$(node -p 'process.arch')   # x64 | arm64

# 1. Native blobs for platforms this image can never run.
find "$PNPM_HOME" -type f -size +5M \
    \( -path "*/darwin/*" -o -path "*/win32/*" -o -name "*.exe" \
       -o \( -path "*/linux/*" ! -path "*/linux/${NODE_ARCH}/*" \) \) \
    -print | prune_inodes

# 2. Browser-only wasm runtime — node code paths use onnxruntime-node.
find "$PNPM_HOME" -type f -size +5M -path "*onnxruntime-web*" -print | prune_inodes

# 3. The Agent SDK's bundled claude duplicates the binary the Dockerfile
#    already bakes at /usr/local/bin/claude — swap it for a symlink.
find "$PNPM_HOME" -type f -size +100M -path "*claude-agent-sdk*" -name claude \
    -print | while IFS= read -r f; do
        find "$PNPM_HOME" -samefile "$f" ! -path "$f" -delete || true
        rm -f "$f"
        ln -s /usr/local/bin/claude "$f"
done

# 4. Orphaned store payloads left behind by the pruning above.
find "$PNPM_HOME" -type f -size +5M -links 1 -delete

# --- verify the pruning did not eat anything the CLIs need ---
# The find-based deletion above is heuristic: a mis-sized or mis-pathed match
# would silently strip a package payload and only surface as a broken command
# inside a running container. Fail the build here instead.
broken=0
for link in "$PNPM_HOME/bin"/*; do
    [ -e "$link" ] && continue
    [ -L "$link" ] || continue   # unmatched glob, not a broken entry
    echo "dangling global bin after prune: $link -> $(readlink "$link")" >&2
    broken=1
done
if ! pnpm list -g --depth=0 >/dev/null; then
    echo "pnpm can no longer read its global store after pruning" >&2
    broken=1
fi
[ "$broken" -eq 0 ]
