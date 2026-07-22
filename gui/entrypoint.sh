#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=gui/vncpass.sh
source /usr/local/bin/gui-vncpass
provision_vncpass

/usr/local/bin/gui-supervisor &
supervisor_pid=$!

cleanup() {
    kill "${supervisor_pid}" >/dev/null 2>&1 || true
    wait "${supervisor_pid}" 2>/dev/null || true
}
trap cleanup EXIT

for _ in {1..60}; do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

if ! xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    echo "gui-entrypoint: X display ${DISPLAY} did not become ready" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    set -- bash
fi

exec "$@"
