# Sandbox Images

Container images for [Wallfacer](https://github.com/changkun/wallfacer) agent sandboxes.

## Images

- **sandbox-claude** — Claude Code CLI sandbox
  `ghcr.io/latere-ai/sandbox-claude`
- **sandbox-codex** — OpenAI Codex CLI sandbox
  `ghcr.io/latere-ai/sandbox-codex`

## What's inside

Both images share a common base (Ubuntu 24.04, multi-arch amd64/arm64):

- **OS** — Ubuntu 24.04 with `build-essential`, `git`, `curl`, `wget`, `vim`, `jq`, `ripgrep`, `openssh-client`
- **Go** — 1.25.7 + tooling (gopls, goimports, delve, golangci-lint, staticcheck, gosec, and more)
- **Node.js** — 22 LTS
- **Python** — 3 with pip and venv
- **Non-root user** — UID 1000, passwordless sudo

Image-specific additions:

- **sandbox-claude**
  - [Claude Code CLI](https://github.com/anthropics/claude-code) (`@anthropic-ai/claude-code`)
  - [RTK](https://github.com/rtk-ai/rtk) — token-optimized CLI proxy for reduced token usage
- **sandbox-codex**
  - [Codex CLI](https://github.com/openai/codex) (`@openai/codex`)

## Using pre-built images

Pre-built multi-arch images are published to GHCR on every release:

```bash
# Pull the latest Claude sandbox
podman pull ghcr.io/latere-ai/sandbox-claude:latest

# Pull a specific version
podman pull ghcr.io/latere-ai/sandbox-claude:v0.0.1

# Same for Codex
podman pull ghcr.io/latere-ai/sandbox-codex:latest
```

Replace `podman` with `docker` if using Docker.

## Building locally

If you want to customize the images or build from source:

```bash
git clone https://github.com/latere-ai/images.git
cd images

make            # Build both images
make claude     # Build Claude sandbox only
make codex      # Build Codex sandbox only
make clean      # Remove all images
```

Override the container runtime (default: `podman`):

```bash
make RUNTIME=docker
```

Built images are tagged as both `sandbox-claude:latest` (local) and `ghcr.io/latere-ai/sandbox-claude:latest` (registry name). Wallfacer finds images by the local name, so local builds work without any configuration change.

## Entrypoint contract

Wallfacer expects the following from sandbox images:

- **Working directory** — `/workspace` (workspaces are mounted as subdirectories)
- **User** — non-root (UID 1000)
- **Entrypoint** — accepts Claude Code-compatible flags (`-p <prompt>`, `--verbose`, `--output-format stream-json`, `--model <model>`, `--resume <session>`)
- **Output** — last line of stdout must be a JSON object with `{result, session_id, stop_reason, is_error, total_cost_usd, usage}`
- **Environment variables** — receives `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN` (Claude) or `OPENAI_API_KEY` (Codex) via `--env-file`
- **Config volume** — Claude config mounted at `/home/<user>/.claude`
