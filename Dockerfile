# Minimal CI image for self-hosted GitHub Actions / Forgejo Actions runners.
# Jobs run directly inside this container (no Docker CLI, no docker.sock).
# Node.js is bundled because `uses:` actions (e.g. actions/checkout) run with node.

# Versions are build args / FROM tags, kept up to date by Renovate (renovate.json).
# PYTHON_VERSION / NODE_VERSION select the build variant (see the CI matrix).
ARG UV_VERSION=0.11.23
ARG PYTHON_VERSION=3.13
# renovate: datasource=docker depName=node versioning=node
ARG NODE_VERSION=24.17.0

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv
FROM node:${NODE_VERSION}-trixie-slim AS node

FROM python:${PYTHON_VERSION}-slim-trixie

LABEL org.opencontainers.image.description="A minimal Docker image with Python and essential CI tools, ready for running tests, builds, and other automation tasks."

# renovate: datasource=npm depName=npm
ARG NPM_VERSION=11.17.0
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
RUN printf 'min-release-age=%s\naudit=false\nfund=false\n' "${COOLDOWN_DAYS}" > /etc/npmrc \
 && printf '[install]\nuploaded-prior-to = P%sD\n' "${COOLDOWN_DAYS}" > /etc/pip.conf \
 && mkdir -p /etc/uv \
 && printf 'exclude-newer = "P%sD"\n' "${COOLDOWN_DAYS}" > /etc/uv/uv.toml

RUN python --version && pip --version && git --version \
 && node --version && npm --version && uv --version

CMD ["bash"]
