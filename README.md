# hermes-iris

Hermes Agent image with the operational toolbelt that the Asgard cluster
needs baked in.  Builds on top of upstream `nousresearch/hermes-agent` and
adds:

| Layer | What |
|---|---|
| **K8s ops** | `kubectl`, `helm`, `argocd`, `egctl` |
| **MCP binaries** | `vault-mcp-server`, `mcp-grafana` |
| **Shell QoL** | `gh`, `jq`, `yq`, `lsof`, `mosh`, `ncdu`, `sqlite3`, `tmux`, `vim`, `wget`, `iproute2` |
| **Vault CLI** | `vault` |
| **Package managers** | `pipx`, `pnpm` (with `mcporter` global) |

## Image

```
ghcr.io/thekoma/hermes-iris:<YYYY.MM.N>
ghcr.io/thekoma/hermes-iris:latest
```

## How tags work

CI computes a `YYYY.MM.N` tag on each `main` push (N increments per month).
Renovate bumps the Dockerfile `ARG`s for upstream Hermes and every binary;
a nightly schedule rebuilds against the latest upstream digest.

## Bumping by hand

Edit the relevant `ARG <NAME>=...` in `Dockerfile` and push.  CI builds and
tags automatically.

## Local smoke test

```sh
docker buildx build --platform linux/amd64 --load -t hermes-iris:smoke .
docker run --rm --entrypoint /bin/bash hermes-iris:smoke -c '
  kubectl version --client; helm version --short; argocd version --client --short
  egctl version; vault version; mcp-grafana --help | head -1
  vault-mcp-server --help | head -1; pnpm --version
'
```

## Deployment

Consumed by `applications/odin/hermes/` in
[`thekoma/asgard-k8s`](https://github.com/thekoma/asgard-k8s).
