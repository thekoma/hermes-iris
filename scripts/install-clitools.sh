#!/usr/bin/env bash
# Download pinned argocd, helm, kubectl release binaries into /out and strip
# them. Runs in a throwaway build stage (clitools); the final image only
# COPYs /out/* — curl, binutils & co. never reach the runtime image.
# Vault and Envoy Gateway are covered by their MCP servers — no fat CLIs.
set -euo pipefail
trap 'echo "install-clitools.sh: failed at line $LINENO" >&2' ERR

: "${ARGOCD_VERSION:?ARGOCD_VERSION is required}"
: "${HELM_VERSION:?HELM_VERSION is required}"
: "${KUBECTL_VERSION:?KUBECTL_VERSION is required}"
: "${CLAUDE_CODE_VERSION:?CLAUDE_CODE_VERSION is required}"
: "${ARCH:?ARCH is required (amd64|arm64)}"

# A registry/CDN can answer 200 with an error page or a truncated body; curl
# -f only catches HTTP status. Assert we really got a Linux executable so a
# bad download fails here instead of at container runtime.
assert_elf() {
    local path=$1
    [ -s "$path" ] || { echo "$path is missing or empty" >&2; return 1; }
    if [ "$(head -c 4 "$path" | od -An -tx1 | tr -d ' \n')" != "7f454c46" ]; then
        echo "$path is not an ELF binary (got $(file -b "$path" 2>/dev/null || echo unknown))" >&2
        return 1
    fi
}

mkdir -p /out

# --- argocd ---
curl -fsSL \
    "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${ARCH}" \
    -o /out/argocd

# --- helm ---
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
    | tar xz --strip-components=1 -C /out "linux-${ARCH}/helm"

# --- kubectl ---
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    -o /out/kubectl

chmod +x /out/argocd /out/helm /out/kubectl

# --- claude-code (single native binary) ---
# The npm package ships the 236M binary four times over (claude.exe, the
# per-platform package, the agent-sdk copy, the postinstall download);
# the official installer gives us exactly one.
VERSION_NO_V="${CLAUDE_CODE_VERSION#v}"
curl -fsSL https://claude.ai/install.sh | bash -s -- "$VERSION_NO_V"
CLAUDE_BIN="${HOME:-/root}/.local/bin/claude"
if [ ! -e "$CLAUDE_BIN" ]; then
    echo "claude installer exited 0 but $CLAUDE_BIN does not exist" >&2
    exit 1
fi
cp -L "$CLAUDE_BIN" /out/claude
chmod +x /out/claude

for bin in argocd helm kubectl claude; do
    assert_elf "/out/$bin"
done

# Upstream argocd releases ship DWARF debug info (~30% of the binary);
# helm and kubectl are already stripped, so strip is a no-op there.
# claude is a bun-compiled binary — strip would corrupt it, leave it alone.
strip /out/argocd /out/helm /out/kubectl
