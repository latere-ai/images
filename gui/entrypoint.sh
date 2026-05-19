#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${VNC_PASSWORD:-}" ]]; then
    umask 077
    printf "%s\n" "${VNC_PASSWORD}" > "${HOME}/.vncpass"
elif [[ ! -f "${HOME}/.vncpass" ]]; then
    umask 077
    password="$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
    printf "%s\n" "${password}" > "${HOME}/.vncpass"
    echo "gui-entrypoint: generated VNC password: ${password}" >&2
fi

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
