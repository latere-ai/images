# Repository Guidelines

These notes orient agents and human contributors working on the sandbox images in this repo.

## Purpose & Layout

Container images for the Cella sandbox platform. Two images are built from this repo:

- **sandbox-base**: shared base with OS packages, Go (+ tools), Node.js, Python, an instance-aware shell prompt, and a non-root `agent` user
- **sandbox-gui**: base + Xvfb/x11vnc/noVNC/Chromium GUI stack for computer-use sandboxes

## Build & Test Commands

- `make` — build all images locally (base, then gui)
- `make base` — build just the base image
- `make gui` — build the GUI sandbox (depends on base)
- `RUNTIME=docker make` — use Docker instead of Podman
- `sh test.sh [tag]` — verify built images (versions, tools, user, prompt, GUI stack)

## Repository Layout (map)

- `base/` — shared Ubuntu base (Go, Node, Python, shell prompt, `agent` user)
- `gui/` — GUI/VNC sandbox (`entrypoint.sh`, `supervisor.sh`, `chromium-launch`)
- `.github/workflows/release.yml` — multi-arch build + GHCR publish
- `test.sh` — image verification script

## Image Conventions & Tips

- Base is the contract: pin tool versions there and create the non-root `agent` user there; child images inherit both. Keep child images thin.
- Both images run as the non-root `agent` user (UID 1000) with passwordless sudo. Workspaces are mounted under `/workspace`.
- `sandbox-gui` runs an Xvfb display with a window manager, x11vnc, and a noVNC websocket bridge on port 6080; Chrome for Testing is pinned and only built for amd64. The supervisor restarts X/VNC processes; the entrypoint waits for the display before exec'ing the command.

## Coding Style & Conventions

- Dockerfiles: one logical step per `RUN`; group apt installs; clean apt lists in the same layer.
- Shell: `set -euo pipefail`; quote variables; prefer `exec` for the final process.
- Keep tool version pins in `base/` (e.g. `GO_VERSION`, `GOPLS_VERSION`); document non-obvious choices inline.
- CI builds the base multi-arch (amd64/arm64); gui is amd64-only (Chrome for Testing has no Linux arm64 archive). Keep that constraint in mind for native deps.

## Commit & PR Guidelines

- Commit style: short imperative subject (e.g. "Add gui sandbox", "Pin gopls"); group related changes.
- PRs: describe what changed and why; note any base-image impact (it rebuilds all child images).
- Test before pushing: `sh test.sh`.
- CI publishes to GHCR on tags/releases; avoid unrelated version bumps in the same PR.
