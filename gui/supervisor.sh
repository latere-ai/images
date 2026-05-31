#!/usr/bin/env bash
set -euo pipefail

: "${DISPLAY:=:0}"
: "${SCREEN_GEOMETRY:=1280x800x24}"
: "${NOVNC_PORT:=6080}"

pids=()

start_loop() {
    local name="$1"
    shift
    (
        while true; do
            echo "gui-supervisor: starting ${name}" >&2
            set +e
            "$@"
            code=$?
            set -e
            echo "gui-supervisor: ${name} exited with ${code}; restarting" >&2
            sleep 1
        done
    ) &
    pids+=("$!")
}

stop_children() {
    for pid in "${pids[@]}"; do
        kill "$pid" >/dev/null 2>&1 || true
    done
    wait "${pids[@]}" 2>/dev/null || true
}
trap stop_children EXIT INT TERM

start_loop xvfb Xvfb "${DISPLAY}" -screen 0 "${SCREEN_GEOMETRY}" -nolisten tcp -ac
sleep 0.2
start_loop mutter dbus-launch --exit-with-session mutter --x11 --replace
start_loop x11vnc x11vnc -display "${DISPLAY}" -localhost -rfbport 5900 -shared -forever -nolookup -noxdamage -noxfixes -passwdfile "${HOME}/.vncpass"
start_loop websockify websockify --web /usr/share/novnc "${NOVNC_PORT}" localhost:5900

wait -n "${pids[@]}"
