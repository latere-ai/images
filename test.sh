#!/bin/bash
#
# Verify sandbox images are functional.
# Usage: sh test.sh [tag]    (default: latest)
#
set -euo pipefail

TAG="${1:-latest}"
RUNTIME="${RUNTIME:-podman}"
REGISTRY="${REGISTRY:-ghcr.io/latere-ai}"
FAILURES=0

pass() { printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
section() { printf "\n\033[1m%s\033[0m\n" "$1"; }

run_in() {
    local image="$1"; shift
    $RUNTIME run --rm --entrypoint bash "$image" -c "$*" 2>&1
}

# --- Base image ---
section "sandbox-base:${TAG}"
BASE="${REGISTRY}/sandbox-base:${TAG}"

out=$(run_in "$BASE" 'go version') && [[ "$out" == *"go1."* ]] \
    && pass "go: $out" || fail "go not found"

out=$(run_in "$BASE" 'node --version') && [[ "$out" == v* ]] \
    && pass "node: $out" || fail "node not found"

out=$(run_in "$BASE" 'python3 --version') && [[ "$out" == *"Python"* ]] \
    && pass "python3: $out" || fail "python3 not found"

for tool in gopls dlv goimports golangci-lint staticcheck gosec; do
    run_in "$BASE" "which $tool" >/dev/null 2>&1 \
        && pass "go tool: $tool" || fail "go tool missing: $tool"
done

out=$(run_in "$BASE" 'pwd') && [[ "$out" == "/workspace" ]] \
    && pass "workdir: /workspace" || fail "workdir is $out, expected /workspace"

# --- Claude image ---
section "sandbox-claude:${TAG}"
CLAUDE="${REGISTRY}/sandbox-claude:${TAG}"

out=$(run_in "$CLAUDE" 'whoami') && [[ "$out" == "claude" ]] \
    && pass "user: claude" || fail "user is $out, expected claude"

out=$(run_in "$CLAUDE" 'echo $HOME') && [[ "$out" == "/home/claude" ]] \
    && pass "home: /home/claude" || fail "home is $out"

out=$(run_in "$CLAUDE" 'claude --version') && [[ "$out" == *"Claude Code"* ]] \
    && pass "claude cli: $out" || fail "claude cli not found"

out=$(run_in "$CLAUDE" 'go version') \
    && pass "go (inherited): $out" || fail "go not inherited from base"

out=$(run_in "$CLAUDE" 'node --version') \
    && pass "node (inherited): $out" || fail "node not inherited from base"

run_in "$CLAUDE" 'test -d /workspace' \
    && pass "workspace dir exists" || fail "/workspace missing"

run_in "$CLAUDE" 'test -w /workspace' \
    && pass "workspace writable" || fail "/workspace not writable"

# --- Codex image ---
section "sandbox-codex:${TAG}"
CODEX="${REGISTRY}/sandbox-codex:${TAG}"

out=$(run_in "$CODEX" 'whoami') && [[ "$out" == "codex" ]] \
    && pass "user: codex" || fail "user is $out, expected codex"

out=$(run_in "$CODEX" 'echo $HOME') && [[ "$out" == "/home/codex" ]] \
    && pass "home: /home/codex" || fail "home is $out"

out=$(run_in "$CODEX" 'codex --version') && [[ -n "$out" ]] \
    && pass "codex cli: $out" || fail "codex cli not found"

out=$(run_in "$CODEX" 'go version') \
    && pass "go (inherited): $out" || fail "go not inherited from base"

out=$(run_in "$CODEX" 'node --version') \
    && pass "node (inherited): $out" || fail "node not inherited from base"

run_in "$CODEX" 'test -d /workspace' \
    && pass "workspace dir exists" || fail "/workspace missing"

run_in "$CODEX" 'test -w /workspace' \
    && pass "workspace writable" || fail "/workspace not writable"

# --- Agents image (unified Claude + Codex) ---
section "sandbox-agents:${TAG}"
AGENTS="${REGISTRY}/sandbox-agents:${TAG}"

out=$(run_in "$AGENTS" 'whoami') && [[ "$out" == "agent" ]] \
    && pass "user: agent" || fail "user is $out, expected agent"

out=$(run_in "$AGENTS" 'echo $HOME') && [[ "$out" == "/home/agent" ]] \
    && pass "home: /home/agent" || fail "home is $out"

out=$(run_in "$AGENTS" 'claude --version') && [[ "$out" == *"Claude Code"* ]] \
    && pass "claude cli: $out" || fail "claude cli not found"

out=$(run_in "$AGENTS" 'codex --version') && [[ -n "$out" ]] \
    && pass "codex cli: $out" || fail "codex cli not found"

out=$(run_in "$AGENTS" 'go version') \
    && pass "go (inherited): $out" || fail "go not inherited from base"

run_in "$AGENTS" 'test -d /workspace' \
    && pass "workspace dir exists" || fail "/workspace missing"

run_in "$AGENTS" 'test -w /workspace' \
    && pass "workspace writable" || fail "/workspace not writable"

# The dispatcher must reject unknown WALLFACER_AGENT values so wallfacer
# can catch misconfiguration loudly instead of defaulting silently.
out=$($RUNTIME run --rm -e WALLFACER_AGENT=bogus "$AGENTS" --help 2>&1 || true)
if echo "$out" | grep -q "unknown WALLFACER_AGENT"; then
    pass "dispatcher rejects unknown agent"
else
    fail "dispatcher did not reject WALLFACER_AGENT=bogus (got: ${out:0:80})"
fi

# --- Smoke tests (requires credentials) ---
# Set ENV_FILE to an env file with CLAUDE_CODE_OAUTH_TOKEN / OPENAI_API_KEY
# to run real prompt tests. Skipped if ENV_FILE is not set.
ENV_FILE="${ENV_FILE:-}"
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
    section "smoke: claude (live prompt)"
    out=$($RUNTIME run --rm \
        --env-file "$ENV_FILE" \
        -v claude-config:/home/claude/.claude \
        "$CLAUDE" \
        -p "who are you? answer in one sentence." \
        --verbose --output-format stream-json 2>&1 | tail -1)
    if echo "$out" | grep -q '"result"'; then
        result=$(echo "$out" | jq -r '.result // empty' 2>/dev/null)
        pass "claude replied: ${result:0:80}"
    else
        fail "claude did not produce a result"
    fi

    section "smoke: codex (live prompt)"
    # Mount only auth.json read-only; codex 0.120+ writes config.toml
    # and sessions into ~/.codex at startup, so the directory itself
    # must be writable inside the container. A read-only mount of the
    # whole dir fails with "failed to persist config.toml".
    CODEX_AUTH_ARGS=""
    if [ -f "${HOME}/.codex/auth.json" ]; then
        CODEX_AUTH_ARGS="-v ${HOME}/.codex/auth.json:/home/codex/.codex/auth.json:ro"
    fi
    out=$($RUNTIME run --rm \
        --env-file "$ENV_FILE" \
        $CODEX_AUTH_ARGS \
        "$CODEX" \
        -p "who are you? answer in one sentence." \
        --verbose --output-format stream-json 2>&1 | tail -1)
    if echo "$out" | grep -q '"result"'; then
        result=$(echo "$out" | jq -r '.result // empty' 2>/dev/null)
        pass "codex replied: ${result:0:80}"
    else
        fail "codex did not produce a result"
    fi

    section "smoke: agents (claude dispatch)"
    out=$($RUNTIME run --rm \
        --env-file "$ENV_FILE" \
        -e WALLFACER_AGENT=claude \
        -v agents-claude-config:/home/agent/.claude \
        "$AGENTS" \
        -p "who are you? answer in one sentence." \
        --verbose --output-format stream-json 2>&1 | tail -1)
    if echo "$out" | grep -q '"result"'; then
        result=$(echo "$out" | jq -r '.result // empty' 2>/dev/null)
        pass "agents/claude replied: ${result:0:80}"
    else
        fail "agents/claude did not produce a result"
    fi

    section "smoke: agents (codex dispatch)"
    # Mount only auth.json read-only so codex can still write its own
    # config.toml / sessions into the in-container ~/.codex/ without
    # touching host state. The Dockerfile pre-creates ~/.codex so the
    # runtime does not have to create the parent dir as root.
    AGENTS_CODEX_AUTH_ARGS=""
    if [ -f "${HOME}/.codex/auth.json" ]; then
        AGENTS_CODEX_AUTH_ARGS="-v ${HOME}/.codex/auth.json:/home/agent/.codex/auth.json:ro"
    fi
    out=$($RUNTIME run --rm \
        --env-file "$ENV_FILE" \
        -e WALLFACER_AGENT=codex \
        $AGENTS_CODEX_AUTH_ARGS \
        "$AGENTS" \
        -p "who are you? answer in one sentence." \
        --verbose --output-format stream-json 2>&1 | tail -1)
    if echo "$out" | grep -q '"result"'; then
        result=$(echo "$out" | jq -r '.result // empty' 2>/dev/null)
        pass "agents/codex replied: ${result:0:80}"
    else
        fail "agents/codex did not produce a result"
    fi
else
    section "smoke tests skipped (set ENV_FILE to enable)"
fi

# --- Summary ---
echo
if [ "$FAILURES" -eq 0 ]; then
    printf "\033[32mAll checks passed.\033[0m\n"
else
    printf "\033[31m%d check(s) failed.\033[0m\n" "$FAILURES"
    exit 1
fi
