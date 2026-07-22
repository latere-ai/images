#!/usr/bin/env bash
#
# VNC password provisioning for the gui image. Sourced by
# entrypoint.sh; defines provision_vncpass and has no side effects on
# its own so it can be exercised without starting a display.

# provision_vncpass writes ${HOME}/.vncpass, the passwdfile x11vnc
# reads. VNC_PASSWORD wins when set; otherwise a password is generated
# on first boot only. The file (mode 0600) is the only retrieval
# channel: the password is never logged.
provision_vncpass() {
    if [[ -n "${VNC_PASSWORD:-}" ]]; then
        umask 077
        printf "%s\n" "${VNC_PASSWORD}" > "${HOME}/.vncpass"
    elif [[ ! -f "${HOME}/.vncpass" ]]; then
        umask 077
        # VncAuth truncates the password to 8 bytes, so 8 characters is
        # the ceiling regardless of how much is generated. A base64
        # alphabet buys ~48 bits at that length where hex buys 32. The
        # input is over-read so stripping the non-alphanumerics still
        # leaves 8 characters.
        password="$(head -c 24 /dev/urandom | base64 | tr -d '=+/\n' | cut -c1-8)"
        printf "%s\n" "${password}" > "${HOME}/.vncpass"
    fi
}
