# syntax=docker/dockerfile:1.7
# Hermes Agent image with k8s + MCP toolbelt baked on top of upstream.

# Global ARG — must be declared before the first FROM so subsequent FROM
# directives can substitute it.  See: https://docs.docker.com/reference/dockerfile/#scope
# renovate: datasource=docker depName=nousresearch/hermes-agent
ARG HERMES_VERSION=latest

# ---------- Stage 1: Go MCP servers ----------
FROM golang:1.26-alpine AS gobuilder

# renovate: datasource=github-releases depName=grafana/mcp-grafana
ARG MCP_GRAFANA_VERSION=v0.15.2
# renovate: datasource=github-releases depName=hashicorp/vault-mcp-server
ARG VAULT_MCP_SERVER_VERSION=v0.2.0

WORKDIR /go
ENV CGO_ENABLED=0
RUN apk add --no-cache git make bash

RUN go install github.com/grafana/mcp-grafana/cmd/mcp-grafana@${MCP_GRAFANA_VERSION}

RUN git clone --depth 1 --branch ${VAULT_MCP_SERVER_VERSION} \
        https://github.com/hashicorp/vault-mcp-server.git && \
    cd vault-mcp-server && make build && \
    cp bin/vault-mcp-server /go/bin/vault-mcp-server

RUN ls -altr /go/bin

# ---------- Stage 2: hermes base + extra tools ----------
# HERMES_VERSION is declared globally above; ${HERMES_VERSION} substitutes here.
FROM nousresearch/hermes-agent:${HERMES_VERSION}

USER root

# --- apt packages (shell QoL on top of upstream's set) ---
COPY scripts/install-system-pkgs.sh /tmp/scripts/install-system-pkgs.sh
RUN /tmp/scripts/install-system-pkgs.sh

# --- pinned CLI binary downloads ---
# renovate: datasource=github-releases depName=argoproj/argo-cd
ARG ARGOCD_VERSION=v3.4.3
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=v4.2.0
# renovate: datasource=github-releases depName=envoyproxy/gateway
ARG EGCTL_VERSION=v1.5.0
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.35.1
# renovate: datasource=github-releases depName=hashicorp/vault
ARG VAULT_CLI_VERSION=v1.20.0

COPY scripts/install-clitools.sh /tmp/scripts/install-clitools.sh
RUN ARGOCD_VERSION="$ARGOCD_VERSION" \
    HELM_VERSION="$HELM_VERSION" \
    EGCTL_VERSION="$EGCTL_VERSION" \
    KUBECTL_VERSION="$KUBECTL_VERSION" \
    VAULT_CLI_VERSION="$VAULT_CLI_VERSION" \
    /tmp/scripts/install-clitools.sh

# --- Go MCP server binaries from the gobuilder stage ---
COPY --from=gobuilder /go/bin/mcp-grafana       /usr/local/bin/mcp-grafana
COPY --from=gobuilder /go/bin/vault-mcp-server  /usr/local/bin/vault-mcp-server

# --- pipx + pnpm globals ---
ENV PIPX_HOME=/opt/pipx
ENV PIPX_BIN_DIR=/usr/local/bin
ENV PIP_NO_CACHE_DIR=1
ENV PNPM_HOME=/usr/local/share/pnpm
ENV PATH="$PNPM_HOME/bin:$PATH"

COPY scripts/install-global-pnpm.sh /tmp/scripts/install-global-pnpm.sh
RUN apt-get update && \
    apt-get install -yq --no-install-recommends pipx && \
    /tmp/scripts/install-global-pnpm.sh && \
    chown -R 10000:10000 "$PNPM_HOME" /opt/pipx && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Cleanup our staging dir.
RUN rm -rf /tmp/scripts

# IMPORTANT: do not redefine ENTRYPOINT or CMD — the upstream image sets
#   ENTRYPOINT ["/init", "/opt/hermes/docker/main-wrapper.sh"]
#   CMD []
# which routes args through s6-overlay and the privilege-drop shim.  Our
# kubernetes manifest passes `args: ["gateway", "run"]` at runtime.

# Re-assume the unprivileged user defined by upstream (UID 10000).
USER hermes
