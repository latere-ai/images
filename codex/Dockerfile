ARG BASE_IMAGE=sandbox-base:latest
FROM ${BASE_IMAGE}

# --- Non-root user ---
ARG USERNAME=codex
ARG USER_UID=1000
ARG USER_GID=1000
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true && \
    groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chown ${USERNAME}:${USERNAME} /workspace

USER ${USERNAME}
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global
ENV PATH=$PATH:/home/${USERNAME}/.npm-global/bin
ENV GOPATH=/home/${USERNAME}/go
ENV PATH=$PATH:/home/${USERNAME}/go/bin:/home/${USERNAME}/.local/bin

# --- OpenAI Codex CLI ---
RUN npm install -g @openai/codex

# Pre-create ~/.codex so callers can bind-mount a single file
# (e.g. ~/.codex/auth.json:/home/codex/.codex/auth.json:ro) without
# the runtime creating the parent dir as root. Codex 0.120+ writes
# config.toml and session state into this dir at startup.
RUN mkdir -p /home/${USERNAME}/.codex && chmod 700 /home/${USERNAME}/.codex

# --- Entrypoint ---
COPY --chown=${USERNAME}:${USERNAME} entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
