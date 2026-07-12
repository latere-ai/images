#!/bin/bash
#
# Everything derived from catalog.yaml: linting, the CI change filters
# and build matrices, the published catalog.json, and local builds.
#
# Usage:
#   ./catalog.sh lint [workflow-file]      validate catalog.yaml (+ grep gate)
#   ./catalog.sh filters                   paths-filter YAML for CI
#   ./catalog.sh matrix <changed|--all>    build matrices from a changed set
#                                          (changed = JSON array of image names)
#   ./catalog.sh compose <tag> <commit> <digest-dir>
#                                          print catalog.json (digest-dir holds
#                                          one {"name","digest"} JSON per image)
#   ./catalog.sh build [context...]        build images locally (RUNTIME=podman)
#   ./catalog.sh clean                     remove locally built images
#
set -euo pipefail
cd "$(dirname "$0")"

CATALOG=catalog.yaml
RUNTIME="${RUNTIME:-podman}"

command -v yq >/dev/null || { echo "catalog.sh: yq is required (https://github.com/mikefarah/yq)" >&2; exit 1; }
command -v jq >/dev/null || { echo "catalog.sh: jq is required" >&2; exit 1; }

json() { yq -o=json "$CATALOG"; }

lint() {
    local workflow="${1:-.github/workflows/release.yml}" errors=0
    err() { echo "lint: $1" >&2; errors=$((errors + 1)); }

    json >/dev/null || { echo "lint: $CATALOG does not parse" >&2; exit 1; }
    [[ "$(json | jq -r '.version')" == "1" ]] || err "version must be 1"
    [[ -n "$(json | jq -r '.registry // ""')" ]] || err "registry is required"

    local names
    names=$(json | jq -r '.images[].name')
    [[ -n "$names" ]] || err "images list is empty"
    [[ "$(sort <<<"$names" | uniq -d)" == "" ]] || err "duplicate image names"
    [[ "$(json | jq -r '.images[].context' | sort | uniq -d)" == "" ]] || err "duplicate contexts"

    local i n ctx from count
    count=$(json | jq '.images | length')
    for ((i = 0; i < count; i++)); do
        n=$(json | jq -r ".images[$i].name // \"\"")
        ctx=$(json | jq -r ".images[$i].context // \"\"")
        from=$(json | jq -r ".images[$i].from // \"\"")
        [[ "$n" =~ ^[a-z0-9][a-z0-9-]*$ ]] || err "images[$i]: bad or missing name '$n'"
        [[ -f "$ctx/Dockerfile" ]] || err "$n: context '$ctx' has no Dockerfile"
        [[ "$(json | jq ".images[$i].platforms | length")" -gt 0 ]] || err "$n: platforms is required"
        [[ -n "$(json | jq -r ".images[$i].label // \"\"")" ]] || err "$n: label is required"
        [[ -n "$(json | jq -r ".images[$i].description // \"\"")" ]] || err "$n: description is required"
        if [[ -n "$from" ]]; then
            json | jq -e ".images[:$i] | map(.name) | index(\"$from\")" >/dev/null \
                || err "$n: from '$from' must be declared earlier in the list"
        fi
        json | jq -e ".images[$i].defaults // {} | keys - [\"cpu_milli\",\"memory_mb\",\"width\",\"height\"] == []" >/dev/null \
            || err "$n: unknown defaults key"
    done

    # The workflow must stay fully catalog-driven: no image name may
    # appear in it as a literal.
    if [[ -f "$workflow" ]]; then
        for n in $names; do
            if grep -q "$n" "$workflow"; then
                err "$workflow hardcodes image name '$n'"
            fi
        done
    fi

    [[ "$errors" -eq 0 ]] || exit 1
    echo "lint: ok ($count images)"
}

filters() {
    json | jq -r '.images[] | "\(.name):\n  - \(.context)/**"'
}

# matrix <changed> — <changed> is a JSON array of image names (from
# paths-filter) or --all. Rebuilds propagate along `from` edges; a single
# in-order pass suffices because lint enforces that `from` targets are
# declared earlier. Roots (no `from`) and deps build as separate stages.
matrix() {
    local changed="${1:?usage: catalog.sh matrix <changed-json|--all>}"
    if [[ "$changed" == "--all" ]]; then
        changed=$(json | jq -c '[.images[].name]')
    fi
    json | jq -c --argjson c0 "$changed" '
        .registry as $reg
        | (.images | reduce .[] as $i ($c0;
            if (index($i.name) == null) and ($i.from != null) and (index($i.from) != null)
            then . + [$i.name] else . end)) as $sel
        | [.images[] | select(.name as $n | $sel | index($n))] as $imgs
        | ($imgs | map(select(.from == null)
            | {name, context, platforms: (.platforms | join(","))})) as $roots
        | ($imgs | map(select(.from != null)
            | {name, context, from, platforms: (.platforms | join(","))})) as $deps
        | {registry: $reg,
           roots: {image: $roots}, any_root: ($roots | length > 0),
           deps: {image: $deps}, any_dep: ($deps | length > 0)}'
}

# compose <tag> <commit> <digest-dir> — join catalog.yaml with the digests
# recorded by the build jobs into the published catalog.json contract.
compose() {
    local tag="${1:?usage: catalog.sh compose <tag> <commit> <digest-dir>}"
    local commit="${2:?commit required}"
    local dir="${3:?digest dir required}"
    local digests
    digests=$(jq -s 'map({(.name): .digest}) | add // {}' "$dir"/*.json 2>/dev/null || echo '{}')
    json | jq --arg tag "$tag" --arg commit "$commit" \
              --arg repo "${GITHUB_REPOSITORY:-latere-ai/images}" \
              --argjson digests "$digests" '
        .registry as $reg
        | {version: 1,
           source: {repo: $repo, commit: $commit, tag: $tag},
           images: [.images[]
             | . as $i
             | ($digests[$i.name] // "") as $d
             | if $d == "" then error("missing digest for \($i.name)") else . end
             | {name, ref: "\($reg)/\(.name):\($tag)", digest: $d,
                platforms, label, description}
               + (if $i.defaults then {defaults: $i.defaults} else {} end)]}'
}

# build [context...] — local build via $RUNTIME, tagging <name>:latest and
# <registry>/<name>:latest. No args builds everything in catalog order;
# with args, each context's `from` chain builds first.
build_one() {
    local ctx="$1" entry name from args=()
    entry=$(json | jq -c ".images[] | select(.context == \"$ctx\")")
    [[ -n "$entry" ]] || { echo "build: unknown context '$ctx'" >&2; exit 1; }
    name=$(jq -r '.name' <<<"$entry")
    from=$(jq -r '.from // ""' <<<"$entry")
    if [[ -n "$from" ]]; then
        build_one "$(json | jq -r ".images[] | select(.name == \"$from\") | .context")"
        args+=(--build-arg "BASE_IMAGE=$from:latest")
    fi
    local reg
    reg=$(json | jq -r '.registry')
    echo "build: $name ($ctx)"
    $RUNTIME build "${args[@]}" -t "$name:latest" -t "$reg/$name:latest" \
        -f "$ctx/Dockerfile" "$ctx/"
}

build() {
    if [[ $# -eq 0 ]]; then
        local ctx
        for ctx in $(json | jq -r '.images[].context'); do build_one "$ctx"; done
    else
        local c
        for c in "$@"; do build_one "$c"; done
    fi
}

clean() {
    local reg n
    reg=$(json | jq -r '.registry')
    for n in $(json | jq -r '.images[].name'); do
        $RUNTIME rmi "$n:latest" "$reg/$n:latest" 2>/dev/null || true
    done
}

cmd="${1:-}"
shift || true
case "$cmd" in
    lint)    lint "$@" ;;
    filters) filters ;;
    matrix)  matrix "$@" ;;
    compose) compose "$@" ;;
    build)   build "$@" ;;
    clean)   clean ;;
    *)       grep '^#' "$0" | sed -n '2,15p' >&2; exit 1 ;;
esac
