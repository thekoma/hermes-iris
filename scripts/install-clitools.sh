#!/usr/bin/env bash
# Download pinned argocd, helm, egctl, kubectl, vault CLI release binaries.
# Versions are passed as env vars from the Dockerfile (ARG → ENV → here).
set -euo pipefail

: "${ARGOCD_VERSION:?ARGOCD_VERSION is required}"
: "${HELM_VERSION:?HELM_VERSION is required}"
: "${EGCTL_VERSION:?EGCTL_VERSION is required}"
: "${KUBECTL_VERSION:?KUBECTL_VERSION is required}"
: "${VAULT_CLI_VERSION:?VAULT_CLI_VERSION is required}"

ARCH=$(dpkg --print-architecture)

apt-get update
apt-get install -yq --no-install-recommends unzip
rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# --- argocd ---
curl -fsSL \
    "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${ARCH}" \
    -o /usr/local/bin/argocd
chmod +x /usr/local/bin/argocd

# --- helm ---
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" \
    | tar xz --strip-components=1 -C /usr/local/bin "linux-${ARCH}/helm"
chmod +x /usr/local/bin/helm

# --- egctl (Envoy Gateway CLI) ---
curl -fsSL \
    "https://github.com/envoyproxy/gateway/releases/download/${EGCTL_VERSION}/egctl_${EGCTL_VERSION}_linux_${ARCH}.tar.gz" \
    | tar xz --strip-components=3 -C /usr/local/bin "bin/linux/${ARCH}/egctl"
chmod +x /usr/local/bin/egctl

# --- kubectl ---
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# --- vault CLI ---
VAULT_VER_NO_V="${VAULT_CLI_VERSION#v}"
curl -fsSL \
    "https://releases.hashicorp.com/vault/${VAULT_VER_NO_V}/vault_${VAULT_VER_NO_V}_linux_${ARCH}.zip" \
    -o /tmp/vault.zip
unzip -p /tmp/vault.zip vault > /usr/local/bin/vault
chmod +x /usr/local/bin/vault
rm -f /tmp/vault.zip
