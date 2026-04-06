# Sandbox Images

Container images for [Wallfacer](https://github.com/changkun/wallfacer) agent sandboxes.

## Images

- **sandbox-base**: shared base image with OS packages, Go, Go tools, Node.js, Python, and RTK
  `ghcr.io/latere-ai/sandbox-base`
- **sandbox-claude**: Claude Code CLI sandbox
  `ghcr.io/latere-ai/sandbox-claude`
- **sandbox-codex**: OpenAI Codex CLI sandbox
  `ghcr.io/latere-ai/sandbox-codex`

## What's inside

The base image (Ubuntu 24.04, multi-arch amd64/arm64) provides:

- **OS**: Ubuntu 24.04 with `build-essential`, `git`, `curl`, `wget`, `vim`, `jq`, `ripgrep`, `openssh-client`
- **Go**: 1.25.7 + tooling (gopls, goimports, delve, golangci-lint, staticcheck, gosec, and more)
- **Node.js**: 22 LTS
- **Python**: 3 with pip and venv
- **Non-root user**: UID 1000, passwordless sudo
- **[RTK](https://github.com/rtk-ai/rtk)**: token-optimized CLI proxy for reduced token usage

Image-specific additions:

- **sandbox-claude**
  - [Claude Code CLI](https://github.com/anthropics/claude-code) (`@anthropic-ai/claude-code`)
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

```bash
git clone https://github.com/latere-ai/images.git
cd images

make            # Build all images (base, claude, codex)
make base       # Build base image only
make claude     # Build Claude sandbox (builds base first)
make codex      # Build Codex sandbox (builds base first)
make clean      # Remove all images
```

Override the container runtime (default: `podman`):

```bash
make RUNTIME=docker
```

Built images are tagged as both `sandbox-claude:latest` (local) and `ghcr.io/latere-ai/sandbox-claude:latest` (registry name). Wallfacer finds images by the local name, so local builds work without any configuration change.

## Running standalone

You can run these images directly without Wallfacer. Each sandbox needs credentials and a workspace directory mounted into the container.

### Claude sandbox

Claude Code authenticates via either an OAuth token or an API key. Pass credentials through an env file and mount a named volume for Claude's config directory.

1. Create an env file (e.g. `~/.claude-sandbox.env`):

   ```
   ANTHROPIC_API_KEY=sk-ant-...
   ```

   Or, if using OAuth (from `claude setup-token`):

   ```
   CLAUDE_CODE_OAUTH_TOKEN=your-oauth-token
   ```

2. Run the container:

   ```bash
   docker run --rm -it \
     --env-file ~/.claude-sandbox.env \
     -v claude-config:/home/claude/.claude \
     -v "$(pwd)":/workspace/myproject \
     -w /workspace/myproject \
     ghcr.io/latere-ai/sandbox-claude:latest \
     -p "explain this project"
   ```

The named volume `claude-config` persists Claude's session data, settings, and CLAUDE.md cache between runs. The first run may take a moment while Claude Code initializes.

To start an interactive session instead of a one-shot prompt:

```bash
docker run --rm -it \
  --env-file ~/.claude-sandbox.env \
  -v claude-config:/home/claude/.claude \
  -v "$(pwd)":/workspace/myproject \
  -w /workspace/myproject \
  --entrypoint claude \
  ghcr.io/latere-ai/sandbox-claude:latest
```

### Codex sandbox

Codex authenticates via an API key passed through an env file. If you have logged in with `codex` on the host, you can also bind-mount the auth cache.

1. Create an env file (e.g. `~/.codex-sandbox.env`):

   ```
   OPENAI_API_KEY=sk-...
   ```

2. Run the container:

   ```bash
   docker run --rm -it \
     --env-file ~/.codex-sandbox.env \
     -v "$(pwd)":/workspace/myproject \
     -w /workspace/myproject \
     ghcr.io/latere-ai/sandbox-codex:latest \
     -p "explain this project"
   ```

   Or, if you have `~/.codex/auth.json` from a prior `codex` login on the host, mount it read-only instead of using an env file:

   ```bash
   docker run --rm -it \
     -v ~/.codex:/home/codex/.codex:ro \
     -v "$(pwd)":/workspace/myproject \
     -w /workspace/myproject \
     ghcr.io/latere-ai/sandbox-codex:latest \
     -p "explain this project"
   ```

### Notes

- Replace `docker` with `podman` if preferred.
- The `-p "..."` flag passes a one-shot prompt. The entrypoint translates this into the appropriate CLI invocation.
- Mount additional project directories as needed under `/workspace/`.
- To limit resources: `--cpus 2 --memory 4g`.

## Entrypoint contract

These details are relevant if you are building custom images on top of the sandboxes or integrating them into your own orchestration.

- **Working directory**: `/workspace` (workspaces are mounted as subdirectories)
- **User**: non-root (UID 1000)
- **Entrypoint**: accepts Claude Code-compatible flags (`-p <prompt>`, `--verbose`, `--output-format stream-json`, `--model <val>`, `--resume <val>`)
- **Output**: last line of stdout must be a JSON object with `{result, session_id, stop_reason, is_error, total_cost_usd, usage}`
- **Environment variables**: receives `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN` (Claude) or `OPENAI_API_KEY` (Codex) via `--env-file`
- **Config volume**: Claude config at `/home/claude/.claude`, Codex auth at `/home/codex/.codex`
