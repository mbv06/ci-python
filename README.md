# CI image: Python

[![CI](https://github.com/mbv06/ci-python/actions/workflows/ci.yml/badge.svg)](https://github.com/mbv06/ci-python/actions/workflows/ci.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-ci--python-2496ED?logo=docker&logoColor=white)](https://github.com/mbv06/ci-python/pkgs/container/ci-python)
[![Python](https://img.shields.io/badge/Python-3.11%20%7C%203.13%20%7C%203.14-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Node.js](https://img.shields.io/badge/Node.js-24-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![Renovate](https://img.shields.io/badge/Renovate-enabled-1A1F6C?logo=renovatebot&logoColor=white)](https://docs.renovatebot.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A minimal Docker image with Python and essential CI tools, ready for running tests, builds, and other automation tasks.

Contents: Python + pip, uv, Node.js + npm, git, curl, ca-certificates, build-essential, and common Python build deps (`libffi-dev`, `libssl-dev`, `pkg-config`). Node.js is copied from the [official Node.js Docker image](https://hub.docker.com/_/node) and bundled only so JavaScript-based CI actions (e.g. `actions/checkout@v6`) can run — it is not meant for building Node.js projects.

## Variants

Published as tags of a single image `ghcr.io/mbv06/ci-python`. All variants share the
same Node.js version (pinned in the Dockerfile and updated by Renovate).
Each tag supports both `linux/amd64` and `linux/arm64`.

- `py3.11-node24`, `py3.13-node24`, `py3.14-node24` — a full Python+Node pair
- `py3.11`, `py3.13`, `py3.14` — short aliases for the same pairs
- `py3.13-node24-cd3`, … — variants with a shorter 3-day cooldown
- `latest` — the default variant (Python 3.13)
- `py3.13-node24-sha-<commit>` — commit-addressed tag (written only on push; not retargeted by scheduled rebuilds)

For a truly immutable pin use the image digest (`ghcr.io/mbv06/ci-python@sha256:…`), not a tag.

The supported set is the matrix in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

**Cooldown.** To avoid freshly-published (potentially compromised) packages, the image
ignores releases newer than `COOLDOWN_DAYS` (default `7`), configured system-wide for
npm (`/usr/local/etc/npmrc`), pip (`/etc/pip.conf`) and uv (`/etc/uv/uv.toml`). The `-cd3` tags
use a shorter 3-day window.

## Build

Base-image inputs (`uv`, `node`, `python`) are pinned by digest in the [`Dockerfile`](Dockerfile)
and auditable; Renovate refreshes those digests when the tags move. OS packages installed
via apt are intentionally not pinned and may change on rebuild.

```bash
docker build -t ci-python:py3.13-node24 .
```

Override the Python base (use the matching `PYTHON_IMAGE_*` pin from the Dockerfile)
and cooldown for another variant:

```bash
docker build \
  --build-arg PYTHON_IMAGE=python:3.14-slim-trixie@sha256:<digest> \
  --build-arg COOLDOWN_DAYS=3 \
  -t ci-python:py3.14-node24-cd3 .
```

## Use it as a job container

Reference the image+tag as the container for your CI job:

```yaml
container: ghcr.io/mbv06/ci-python:py3.13-node24
```

## Maintenance

- [`.github/workflows/ci.yml`](.github/workflows/ci.yml): builds and pushes every matrix variant to GHCR via `GITHUB_TOKEN`. Also runs a monthly no-cache rebuild (`schedule`) so OS packages stay fresh even when base digests are unchanged (rolling tags only; commit-addressed SHA tags are push-only). On public repos GitHub disables `schedule` after 60 days without repository activity.
- [`.github/workflows/gitleaks.yml`](.github/workflows/gitleaks.yml): Gitleaks secret scan on every push and pull request (no path filter).
- [`renovate.json`](renovate.json) pins and updates base-image digests (`docker:pinDigests`), plus npm, pip and CI actions. The variant set stays manual in the matrix.
- Cooldown (`COOLDOWN_DAYS`) via `/usr/local/etc/npmrc`, `/etc/pip.conf` and `/etc/uv/uv.toml`; see [Variants](#variants).
