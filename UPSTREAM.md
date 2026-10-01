# Upstream tracking

Base image: [`nousresearch/hermes-agent`](https://github.com/NousResearch/hermes-agent)

## Version pinning

The Dockerfile pins `ARG HERMES_VERSION=latest@sha256:<digest>`, annotated for
Renovate with `# renovate: datasource=docker depName=nousresearch/hermes-agent
versioning=docker`. When upstream moves `latest`, Renovate opens a digest PR and
automerges it; the push to `main` triggers the build. No upstream change, no
build, no new tag.

## Bumping by hand

```sh
digest=$(docker buildx imagetools inspect nousresearch/hermes-agent:latest \
  --format '{{json .Manifest}}' | jq -r .digest)
sed -i "s|^ARG HERMES_VERSION=.*|ARG HERMES_VERSION=latest@${digest}|" Dockerfile
git commit -am "chore(deps): pin hermes-agent to latest@${digest}"
git push
```

## No nightly rebuild

There is no scheduled build. A nightly run only re-tagged identical layers
(GHA cache hits on every step) under a fresh index digest, which opened a
pointless bump PR downstream every day. Builds run on push to `main`, on tags,
and on `workflow_dispatch`.
