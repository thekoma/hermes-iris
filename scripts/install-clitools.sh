#!/usr/bin/env bash
# Download pinned argocd, helm, kubectl release binaries into /out, verify them
# against the publisher's checksum list, and strip them. Runs in a throwaway
# build stage (clitools); the final image only COPYs /out/* — curl, binutils &
# co. never reach the runtime image.
# Vault and Envoy Gateway are covered by their MCP servers — no fat CLIs.
set -euo pipefail

: "${ARGOCD_VERSION:?ARGOCD_VERSION is required}"
: "${HELM_VERSION:?HELM_VERSION is required}"
: "${KUBECTL_VERSION:?KUBECTL_VERSION is required}"
: "${CLAUDE_CODE_VERSION:?CLAUDE_CODE_VERSION is required}"
: "${ARCH:?ARCH is required (amd64|arm64)}"

mkdir -p /out

# Verify a downloaded artefact against an expected SHA-256. A missing or
# malformed checksum is a hard failure: an unverified binary must never reach
# the runtime image.
verify_sha256() {
    local file="$1" expected="$2"
    if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
        echo "no usable sha256 checksum for ${file}" >&2
        exit 1
    fi
    printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null
    echo "sha256 OK: ${file}"
}

# Pick one entry out of a "<sha256>  <filename>" checksum list.
sha256_from_list() {
    local url="$1" name="$2"
    curl -fsSL "$url" | awk -v n="$name" '$2 == n { print $1; exit }'
}

# --- argocd ---
curl -fsSL \
    "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${ARCH}" \
    -o /out/argocd
verify_sha256 /out/argocd "$(sha256_from_list \
    "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/cli_checksums.txt" \
    "argocd-linux-${ARCH}")"

# --- helm ---
# Verify the tarball before unpacking it, not the extracted binary: a tampered
# archive must never be expanded onto the filesystem.
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
    -o /tmp/helm.tar.gz
verify_sha256 /tmp/helm.tar.gz "$(sha256_from_list \
    "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz.sha256sum" \
    "helm-${HELM_VERSION}-linux-${ARCH}.tar.gz")"
tar xzf /tmp/helm.tar.gz --strip-components=1 -C /out "linux-${ARCH}/helm"
rm -f /tmp/helm.tar.gz

# --- kubectl ---
# dl.k8s.io publishes the bare hash, one file per binary.
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    -o /out/kubectl
verify_sha256 /out/kubectl \
    "$(curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256" | tr -d '[:space:]')"

chmod +x /out/argocd /out/helm /out/kubectl

# --- claude-code (single native binary) ---
# The npm package ships the 236M binary four times over (claude.exe, the
# per-platform package, the agent-sdk copy, the postinstall download);
# the official installer gives us exactly one. The installer resolves the
# pinned version and verifies its own download against Anthropic's signed
# release manifest, so no extra checksum step is needed here.
VERSION_NO_V="${CLAUDE_CODE_VERSION#v}"
curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh
bash /tmp/claude-install.sh "$VERSION_NO_V"
rm -f /tmp/claude-install.sh
cp -L "$HOME/.local/bin/claude" /out/claude
chmod +x /out/claude

# Upstream argocd releases ship DWARF debug info (~30% of the binary);
# helm and kubectl are already stripped, so strip is a no-op there.
# claude is a bun-compiled binary — strip would corrupt it, leave it alone.
strip /out/argocd /out/helm /out/kubectl
