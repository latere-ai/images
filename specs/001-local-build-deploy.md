---
title: Local-First Build and Push (images / base + sandboxes)
status: abandoned
depends_on:
  - ../../terraform/specs/local-build-deploy.md
affects:
  - Makefile
  - .github/workflows/release.yml
  - .github/workflows/ci.yml
  - README.md
effort: medium
trigger: parent umbrella; Tier C — release-only (no k8s deploy), base image is multi-arch
created: 2026-05-31
updated: 2026-05-31
author: changkun
dispatched_task_id: null
---

# Local-First Build and Push (images / base + sandboxes)

## Overview

Tier C child of [[local-build-deploy]]. The `images` repo holds foundational OCI images consumed by sandbox/cella and lectio rasterizer (`base/Dockerfile`, `gui/Dockerfile`). It only builds and pushes — there is no k8s deploy. The current matrix-driven workflow does path filtering + multi-arch on base; the local Makefile collapses to a single entry that takes an optional `IMAGE=base|sandbox-gui` selector.

There is no `make deploy` for this repo. `make release` is the only deploy-related target.

## Current state

- `.github/workflows/release.yml` — complex: `changes` job (path filtering), `base` job (rebuild base on `linux/amd64,linux/arm64`), `sandboxes` matrix job (rebuild changed sandboxes, currently just `sandbox-gui` on `linux/amd64`). Push happens only on tag / release / dispatch.
- `Makefile` — exists but has no docker build targets.
- No CI test workflow exists. (Image repos rarely have tests; the build itself is the gate.)

## Acceptance criteria

1. `Makefile` gains a single `release` target with an `IMAGE` selector:
   - `make release IMAGE=base VERSION=v1.2.3` — `docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/latere-ai/sandbox-base:v1.2.3 base/`, push.
   - `make release IMAGE=sandbox-gui VERSION=v1.2.3` — `docker buildx build --platform linux/amd64 -t ghcr.io/latere-ai/sandbox-gui:v1.2.3 gui/`, push.
   - `make release VERSION=v1.2.3` (no IMAGE) — builds and pushes **all** images sequentially (`base` first since sandboxes FROM it). Use `for img in base sandbox-gui; do $(MAKE) release IMAGE=$$img VERSION=$(VERSION); done`.
   - Idempotent: skip push if tag already exists in ghcr.io.
   - `ghcr-login` prereq as in [[local-build-deploy]].
   - **No `deploy` target**: this repo has no k8s deploy.
2. `.github/workflows/release.yml` is **deleted**.
3. `.github/workflows/ci.yml` is **added** — runs `docker build` (no push) on the changed image dirs as a PR smoke check, replacing the equivalent capability in the current release.yml's main-branch builds. No multi-arch in CI (heavy + slow); only `linux/amd64` for the smoke.
4. `README.md` gains a `## Release` section documenting `make release IMAGE=...` and the dependency order (base before sandboxes).
5. Buildx multi-arch setup is documented: `docker buildx create --name multi --use --platform linux/amd64,linux/arm64` (one-time) and qemu emulation prerequisites (`docker run --privileged --rm tonistiigi/binfmt --install all`).
6. `grep -r DO_TOKEN .github/` returns nothing (it never did — included for consistency).

## Non-goals

- A `make deploy` target. This repo has no k8s deploy.
- Cross-image change detection (the current `changes` job's path filtering). Locally, the developer knows what changed; if not, `make release` (no IMAGE) rebuilds everything. The cost is a few extra minutes locally, not a billed runner.
- Touching the in-cluster sandbox runner that pulls these images.

## Implementation notes

- The base image is the longest build (multi-arch + base layers). Document the typical `make release IMAGE=base` time on the dev laptop in the README so the operator knows what to expect.
- buildx with QEMU is slow but works on Apple Silicon. If multi-arch becomes a bottleneck, future work can offload base to a self-hosted ARM runner — not part of this spec.
- Image tag normalization: `VERSION` is passed verbatim (with leading `v`). The current workflow uses `v{{version}}` semver pattern + `:latest` + `:sha-<short>`. Local `make release` pushes only `:v<version>` — explicit, no `latest` drift.

## Doc updates checklist

- [ ] `README.md` — `## Release` section, multi-arch buildx setup, expected build time on a typical dev laptop.

## Verification

1. `cd images && make release IMAGE=base VERSION=v0.0.0-pilot` — `ghcr.io/latere-ai/sandbox-base:v0.0.0-pilot` exists as multi-arch (`docker manifest inspect` shows both platforms).
2. `make release IMAGE=sandbox-gui VERSION=v0.0.0-pilot` — single-arch image pushed.
3. `make release VERSION=v0.0.0-pilot+1` — builds both in order, base first.
4. A PR with a change under `gui/` runs `ci.yml` smoke build but does not push.
5. A `v0.0.0-pilot+2` tag push runs `ci.yml` only — no `release.yml` (it's gone).
6. `grep -r DO_TOKEN .github/` empty.

## Rollback

`git revert` the spec commit. The original `release.yml` is recovered from history.
