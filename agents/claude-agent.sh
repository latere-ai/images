#!/bin/bash
set -e

# Ensure claude config file exists (prevents backup-restore loop)
if [ ! -f "$HOME/.claude.json" ]; then
    echo '{}' > "$HOME/.claude.json"
fi

CLAUDE_ARGS=(--dangerously-skip-permissions)
if [ "${WALLFACER_SANDBOX_FAST:-true}" != "false" ]; then
    CLAUDE_ARGS+=(--append-system-prompt "/fast")
fi
# Honor CLAUDE_DEFAULT_MODEL so standalone invocations (e.g. test.sh,
# `docker run ... -p "..."`) use the same model wallfacer would select.
# Wallfacer always passes --model explicitly; if it's in "$@" below, its
# later position wins, so this is a safe default.
if [ -n "${CLAUDE_DEFAULT_MODEL:-}" ]; then
    CLAUDE_ARGS+=(--model "$CLAUDE_DEFAULT_MODEL")
fi

exec claude "${CLAUDE_ARGS[@]}" "$@"
