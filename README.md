# Sandbox Images

Container images for [Wallfacer](https://github.com/changkun/wallfacer) agent sandboxes.

## Images

| Image | Description | GHCR |
|-------|-------------|------|
| `sandbox-claude` | Claude Code CLI sandbox (Ubuntu 24.04, Go, Node.js, Python) | `ghcr.io/latere-ai/sandbox-claude` |
| `sandbox-codex` | OpenAI Codex CLI sandbox (Ubuntu 24.04, Go, Node.js, Python) | `ghcr.io/latere-ai/sandbox-codex` |

## Build

```bash
make            # Build both images
make claude     # Build Claude sandbox only
make codex      # Build Codex sandbox only
make clean      # Remove all images
```

Override the container runtime (default: `podman`):

```bash
make RUNTIME=docker
```

## Entrypoint Contract

Wallfacer expects the following from sandbox images:

- **Working directory**: `/workspace` (workspaces are mounted as subdirectories)
- **User**: non-root (UID 1000)
- **Entrypoint**: accepts Claude Code-compatible flags (`-p <prompt>`, `--verbose`, `--output-format stream-json`, `--model <model>`, `--resume <session>`)
- **Output**: last line of stdout must be a JSON object with `{result, session_id, stop_reason, is_error, total_cost_usd, usage}`
- **Environment variables**: receives `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN` (Claude) or `OPENAI_API_KEY` (Codex) via `--env-file`
- **Config volume**: Claude config mounted at `/home/<user>/.claude`
