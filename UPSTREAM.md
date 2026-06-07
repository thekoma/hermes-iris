# Upstream tracking

Base image: [`nousresearch/hermes-agent`](https://github.com/NousResearch/hermes-agent)

## Version pinning

The Dockerfile's `ARG HERMES_VERSION=` is annotated for Renovate with
`# renovate: datasource=docker depName=nousresearch/hermes-agent`.  Renovate
opens a PR on every upstream version bump and (per `renovate.json`)
auto-merges minor/patch updates.  Major bumps go to manual review.

## Bumping by hand

```sh
sed -i 's/^ARG HERMES_VERSION=.*/ARG HERMES_VERSION=<new>/' Dockerfile
git commit -am "chore(deps): pin hermes-agent to <new>"
git push
```

## Nightly rebuild

`.github/workflows/release.yaml` includes `schedule: cron "0 3 * * *"`.
Even if no ARGs changed, the nightly run rebuilds against the latest
upstream image digest so security fixes propagate within ~24h.
