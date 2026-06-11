#!/usr/bin/env bash
# Download pinned argocd, helm, kubectl release binaries into /out and strip
# them. Runs in a throwaway build stage (clitools); the final image only
# COPYs /out/* — curl, binutils & co. never reach the runtime image.
# Vault and Envoy Gateway are covered by their MCP servers — no fat CLIs.
set -euo pipefail

: "${ARGOCD_VERSION:?ARGOCD_VERSION is required}"
: "${HELM_VERSION:?HELM_VERSION is required}"
: "${KUBECTL_VERSION:?KUBECTL_VERSION is required}"
: "${ARCH:?ARCH is required (amd64|arm64)}"

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

# Upstream argocd releases ship DWARF debug info (~30% of the binary);
# helm and kubectl are already stripped, so strip is a no-op there.
strip /out/argocd /out/helm /out/kubectl
