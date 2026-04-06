# AGENTS.md

Instructions for AI agents working on this repository.

## Project Overview

Container images for [Wallfacer](https://github.com/changkun/wallfacer) agent sandboxes. Three images are built from this repo:

- **sandbox-base**: shared base with OS packages, Go, Go tools, Node.js, Python, and RTK
- **sandbox-claude**: extends base with the Claude Code CLI
- **sandbox-codex**: extends base with the OpenAI Codex CLI

## Structure

```
base/Dockerfile         Shared base image (Ubuntu 24.04, Go, Node.js, Go tools, RTK)
claude/Dockerfile       Claude Code sandbox (FROM base)
claude/entrypoint.sh    Claude Code entrypoint
codex/Dockerfile        Codex sandbox (FROM base)
codex/entrypoint.sh     Codex entrypoint with argument translation
Makefile                Build targets (base, claude, codex, clean)
.github/workflows/      CI: build-base then build-sandboxes (multi-arch)
```

## Build Commands

```bash
make              # Build all images (base, claude, codex)
make base         # Build base image only
make claude       # Build claude sandbox (builds base first)
make codex        # Build codex sandbox (builds base first)
make clean        # Remove all images
make RUNTIME=docker  # Use Docker instead of Podman
```

## Conventions

- All shared system-level dependencies (OS packages, Go, Go tools, Node.js) go in `base/Dockerfile`. User creation, RTK, and CLI installs go in each child Dockerfile.
- Each image has its own non-root user (UID 1000): `claude` for sandbox-claude, `codex` for sandbox-codex. Wallfacer hardcodes paths under `/home/claude/` and `/home/codex/` for volume mounts, so these usernames must not change.
- Major Go tools are pinned to specific versions via build ARGs. Utility tools use `@latest`.
- RTK version is pinned via the `RTK_VERSION` build ARG.
- Entrypoints handle RTK init at runtime (not build time) because the config volume is mounted at container start.
- The codex entrypoint translates Claude Code-style flags to Codex CLI format and emits a Claude Code-compatible JSON envelope.

## Entrypoint Contract

Wallfacer expects sandbox images to:

- Use `/workspace` as the working directory
- Run as non-root (UID 1000)
- Accept Claude Code-compatible flags (`-p <prompt>`, `--verbose`, `--output-format stream-json`, `--model <val>`, `--resume <val>`)
- Emit a final JSON line: `{result, session_id, stop_reason, is_error, total_cost_usd, usage}`

## CI/CD

The release workflow (`.github/workflows/release.yml`) runs on version tags (`v*`) and manual dispatch:

1. **build-base**: builds and pushes `sandbox-base` (multi-arch amd64/arm64)
2. **build-sandboxes**: builds and pushes `sandbox-claude` and `sandbox-codex` from the pushed base

Images are published to `ghcr.io/latere-ai/`.
