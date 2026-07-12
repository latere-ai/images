#!/bin/bash
#
# Tests for catalog.sh against the live catalog.yaml plus fixtures.
# Usage: sh catalog_test.sh
#
set -euo pipefail
cd "$(dirname "$0")"

FAILURES=0
pass() { printf "  \033[32mPASS\033[0m %s\n" "$1"; }
fail() { printf "  \033[31mFAIL\033[0m %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
section() { printf "\n\033[1m%s\033[0m\n" "$1"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- filters ---
section "filters"
out=$(./catalog.sh filters)
grep -q "^sandbox-base:$" <<<"$out" && grep -q "^  - base/\*\*$" <<<"$out" \
    && pass "base filter emitted" || fail "base filter wrong: $out"
grep -q "^sandbox-gui:$" <<<"$out" && grep -q "^  - gui/\*\*$" <<<"$out" \
    && pass "gui filter emitted" || fail "gui filter wrong: $out"
yq -o=json <<<"$out" >/dev/null 2>&1 \
    && pass "filters output is valid YAML" || fail "filters output is not YAML"

# --- matrix ---
section "matrix"
m=$(./catalog.sh matrix --all)
[[ "$(jq -r '.roots.image[0].name' <<<"$m")" == "sandbox-base" ]] \
    && pass "--all: base in roots" || fail "--all: base missing from roots"
[[ "$(jq -r '.deps.image[0].name' <<<"$m")" == "sandbox-gui" ]] \
    && pass "--all: gui in deps" || fail "--all: gui missing from deps"
[[ "$(jq -r '.roots.image[0].platforms' <<<"$m")" == "linux/amd64,linux/arm64" ]] \
    && pass "--all: platforms joined for buildx" || fail "--all: platforms not joined"
[[ "$(jq -r '.deps.image[0].from' <<<"$m")" == "sandbox-base" ]] \
    && pass "--all: dep carries from" || fail "--all: dep missing from"
[[ "$(jq -r '.registry' <<<"$m")" == "ghcr.io/latere-ai" ]] \
    && pass "--all: registry surfaced" || fail "--all: registry missing"

m=$(./catalog.sh matrix '["sandbox-base"]')
[[ "$(jq -r '.any_root' <<<"$m")" == "true" && "$(jq -r '.any_dep' <<<"$m")" == "true" ]] \
    && pass "base change propagates to gui (from edge)" \
    || fail "base change must rebuild gui: $m"

m=$(./catalog.sh matrix '["sandbox-gui"]')
[[ "$(jq -r '.any_root' <<<"$m")" == "false" && "$(jq -r '.deps.image | length' <<<"$m")" == "1" ]] \
    && pass "gui-only change builds gui alone" || fail "gui-only change wrong: $m"

m=$(./catalog.sh matrix '[]')
[[ "$(jq -r '.any_root' <<<"$m")" == "false" && "$(jq -r '.any_dep' <<<"$m")" == "false" ]] \
    && pass "empty change set builds nothing" || fail "empty change set wrong: $m"

# --- compose ---
section "compose"
mkdir -p "$TMP/digests"
printf '{"name":"sandbox-base","digest":"sha256:aaa"}' > "$TMP/digests/sandbox-base.json"
printf '{"name":"sandbox-gui","digest":"sha256:bbb"}' > "$TMP/digests/sandbox-gui.json"

c=$(./catalog.sh compose v9.9.9 deadbeef "$TMP/digests")
[[ "$(jq -r '.version' <<<"$c")" == "1" ]] \
    && pass "contract version 1" || fail "contract version wrong"
[[ "$(jq -r '.source.tag' <<<"$c")" == "v9.9.9" && "$(jq -r '.source.commit' <<<"$c")" == "deadbeef" ]] \
    && pass "source tag + commit recorded" || fail "source wrong: $(jq -c .source <<<"$c")"
[[ "$(jq -r '.images[0].ref' <<<"$c")" == "ghcr.io/latere-ai/sandbox-base:v9.9.9" ]] \
    && pass "ref pinned to the release tag, not latest" || fail "ref wrong: $(jq -r '.images[0].ref' <<<"$c")"
[[ "$(jq -r '.images[1].digest' <<<"$c")" == "sha256:bbb" ]] \
    && pass "digest joined from build output" || fail "digest join wrong"
[[ "$(jq -r '.images[1].defaults.memory_mb' <<<"$c")" == "1024" ]] \
    && pass "gui defaults carried into contract" || fail "defaults missing"
[[ "$(jq -r '.images[0] | has("defaults")' <<<"$c")" == "false" ]] \
    && pass "base omits defaults" || fail "base must not carry empty defaults"

rm "$TMP/digests/sandbox-gui.json"
if ./catalog.sh compose v9.9.9 deadbeef "$TMP/digests" >/dev/null 2>&1; then
    fail "compose must fail on a missing digest"
else
    pass "compose fails on a missing digest"
fi

# --- lint: live repo (schema only; the workflow grep gate runs in CI
# and is covered by the fixtures below) ---
section "lint"
out=$(./catalog.sh lint /dev/null 2>&1) \
    && pass "live catalog schema lints clean" || fail "live catalog lint: $out"

# --- lint: fixtures ---
fixture() { mkdir -p "$TMP/repo/base" "$TMP/repo/gui"; touch "$TMP/repo/base/Dockerfile" "$TMP/repo/gui/Dockerfile"; cat > "$TMP/repo/catalog.yaml"; cp catalog.sh "$TMP/repo/"; }

fixture <<'EOF'
version: 1
registry: ghcr.io/latere-ai
images:
  - name: sandbox-gui
    context: gui
    platforms: [linux/amd64]
    from: sandbox-base
    label: GUI
    description: x
  - name: sandbox-base
    context: base
    platforms: [linux/amd64]
    label: Base
    description: x
EOF
(cd "$TMP/repo" && ./catalog.sh lint) >/dev/null 2>&1 \
    && fail "lint must reject from-before-declaration" \
    || pass "lint rejects from declared after its dependent"

fixture <<'EOF'
version: 1
registry: ghcr.io/latere-ai
images:
  - name: sandbox-base
    context: missing
    platforms: [linux/amd64]
    label: Base
    description: x
EOF
(cd "$TMP/repo" && ./catalog.sh lint) >/dev/null 2>&1 \
    && fail "lint must reject a context without a Dockerfile" \
    || pass "lint rejects missing Dockerfile"

fixture <<'EOF'
version: 1
registry: ghcr.io/latere-ai
images:
  - name: sandbox-base
    context: base
    platforms: [linux/amd64]
    label: Base
    description: x
  - name: sandbox-base
    context: gui
    platforms: [linux/amd64]
    label: Dup
    description: x
EOF
(cd "$TMP/repo" && ./catalog.sh lint) >/dev/null 2>&1 \
    && fail "lint must reject duplicate names" \
    || pass "lint rejects duplicate names"

fixture <<'EOF'
version: 1
registry: ghcr.io/latere-ai
images:
  - name: sandbox-base
    context: base
    platforms: [linux/amd64]
    label: Base
    description: x
    defaults:
      cpu_milli: 100
      bogus: 1
EOF
(cd "$TMP/repo" && ./catalog.sh lint) >/dev/null 2>&1 \
    && fail "lint must reject unknown defaults keys" \
    || pass "lint rejects unknown defaults keys"

fixture <<'EOF'
version: 1
registry: ghcr.io/latere-ai
images:
  - name: sandbox-base
    context: base
    platforms: [linux/amd64]
    label: Base
    description: x
EOF
mkdir -p "$TMP/repo/.github/workflows"
echo "image: ghcr.io/latere-ai/sandbox-base:latest" > "$TMP/repo/.github/workflows/release.yml"
(cd "$TMP/repo" && ./catalog.sh lint) >/dev/null 2>&1 \
    && fail "grep gate must reject a hardcoded image name in the workflow" \
    || pass "grep gate rejects hardcoded image name in the workflow"
(cd "$TMP/repo" && echo "jobs: {}" > .github/workflows/release.yml && ./catalog.sh lint) >/dev/null 2>&1 \
    && pass "grep gate passes on a catalog-driven workflow" \
    || fail "grep gate false positive"

# --- summary ---
echo
if [ "$FAILURES" -eq 0 ]; then
    printf "\033[32mAll catalog checks passed.\033[0m\n"
else
    printf "\033[31m%d catalog check(s) failed.\033[0m\n" "$FAILURES"
    exit 1
fi
