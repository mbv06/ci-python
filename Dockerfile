# Minimal CI image for self-hosted GitHub Actions / Forgejo Actions runners.
# Jobs run directly inside this container (no Docker CLI, no docker.sock).
# Node.js is bundled because `uses:` actions (e.g. actions/checkout) run with node.

# Base images are pinned by digest (tags alone are mutable). Renovate updates
# tags + digests (docker:pinDigests for FROM lines; customManagers for the
# PYTHON_IMAGE_* matrix pins below).
#
# ARGs used by FROM must be declared before the first FROM.

# CI matrix Python bases. The build selects one with --build-arg PYTHON_IMAGE=...
# (default: 3.13). Kept as ARGs so Renovate can bump each digest independently.
# renovate: datasource=docker depName=python
ARG PYTHON_IMAGE_3_11=python:3.11-slim-trixie@sha256:db3ff2e1800a8581e2c48a27c3995339d47bdf046da21c7627accd3d51053a93
# renovate: datasource=docker depName=python
ARG PYTHON_IMAGE_3_13=python:3.13-slim-trixie@sha256:6771159cd4fa5d9bba1258caf0b82e6b73458c694d178ad97c5e925c2d0e1a91
# renovate: datasource=docker depName=python
ARG PYTHON_IMAGE_3_14=python:3.14-slim-trixie@sha256:cea0e6040540fb2b965b6e7fb5ffa00871e632eef63719f0ea54bca189ce14a6
ARG PYTHON_IMAGE=${PYTHON_IMAGE_3_13}

FROM ghcr.io/astral-sh/uv:0.11.29@sha256:eb2843a1e56fd9e30c7276ce1a52cba86e64c7b385f5e3279a0e08e02dd058fc AS uv
FROM node:24.18.0-trixie-slim@sha256:ae91dcc111a68c9d2d81ff2a17bda61be126426176fde6fe7d08ab13b7f50573 AS node
FROM ${PYTHON_IMAGE}

LABEL org.opencontainers.image.description="A minimal Docker image with Python and essential CI tools, ready for running tests, builds, and other automation tasks."

# renovate: datasource=npm depName=npm
ARG NPM_VERSION=11.18.0
# renovate: datasource=pypi depName=pip versioning=pep440
ARG PIP_VERSION=26.1.2
# Supply-chain cooldown window in days (see the RUN that writes the configs below).
ARG COOLDOWN_DAYS=7

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# OS packages and Python build deps (bash: CI steps assume it).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      git \
      curl \
      ca-certificates \
      build-essential \
      libffi-dev \
      libssl-dev \
      pkg-config \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Node.js from the official image (no external install scripts).
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && ln -s ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack

# uv from its official image (independent of pip).
COPY --from=uv /uv /uvx /usr/local/bin/

# npm/pip must be new enough for the cooldown settings written below.
# pip uses no cache (PIP_NO_CACHE_DIR); drop the npm cache so it doesn't bloat the layer.
RUN npm install -g "npm@${NPM_VERSION}" \
 && python -m pip install --upgrade "pip==${PIP_VERSION}" \
 && npm cache clean --force \
 && rm -rf /root/.npm

# Supply-chain cooldown: ignore packages published in the last COOLDOWN_DAYS days.
# (system-level defaults; a project can still override exclude-newer for uv)
# npm reads $PREFIX/etc/npmrc (/usr/local/etc/npmrc), not /etc/npmrc.
# pip: [global] so uploaded-prior-to applies to install/wheel/download (not only [install]).
RUN mkdir -p /usr/local/etc \
 && printf 'min-release-age=%s\naudit=false\nfund=false\n' "${COOLDOWN_DAYS}" > /usr/local/etc/npmrc \
 && test "$(npm config get min-release-age)" = "${COOLDOWN_DAYS}" \
 && printf '[global]\nuploaded-prior-to = P%sD\n' "${COOLDOWN_DAYS}" > /etc/pip.conf \
 && mkdir -p /etc/uv \
 && printf 'exclude-newer = "P%sD"\n' "${COOLDOWN_DAYS}" > /etc/uv/uv.toml

RUN python --version && pip --version && git --version \
 && node --version && npm --version && uv --version

CMD ["bash"]
