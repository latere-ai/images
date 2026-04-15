#!/bin/bash
# Unified sandbox entrypoint. Dispatches to the Claude Code or Codex
# sub-entrypoint based on WALLFACER_AGENT.
set -e

AGENT="${WALLFACER_AGENT:-claude}"

case "$AGENT" in
    claude)
        exec /usr/local/bin/claude-agent.sh "$@"
        ;;
    codex)
        exec /usr/local/bin/codex-agent.sh "$@"
        ;;
    *)
        echo "sandbox-agents: unknown WALLFACER_AGENT='$AGENT' (expected 'claude' or 'codex')" >&2
        exit 2
        ;;
esac
