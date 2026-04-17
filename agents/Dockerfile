ARG BASE_IMAGE=sandbox-base:latest
FROM ${BASE_IMAGE}

# --- Non-root user ---
# Both Claude Code and Codex run as the same user so a single container
# can switch between agents at exec time. Config directories live
# side-by-side under $HOME (~/.claude, ~/.codex).
ARG USERNAME=agent
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

# --- Agent CLIs ---
ARG CLAUDE_CODE_VERSION=2.1.112
ARG CODEX_VERSION=0.121.0
RUN npm install -g \
      @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
      @openai/codex@${CODEX_VERSION}

# Pre-create the per-CLI config dirs so bind-mounting a single file
# (e.g. ~/.codex/auth.json) does not require the runtime to create the
# parent directory as root — that would leave it unwritable for the
# `agent` user and break codex's attempts to persist config.toml /
# sessions. Owned by the running user, perms match the CLIs' own defaults.
RUN mkdir -p /home/${USERNAME}/.claude /home/${USERNAME}/.codex \
    && chmod 700 /home/${USERNAME}/.claude /home/${USERNAME}/.codex

# --- Entrypoints ---
# entrypoint.sh is a dispatcher that exec's either claude-agent.sh or
# codex-agent.sh based on the WALLFACER_AGENT env var.
COPY --chown=${USERNAME}:${USERNAME} --chmod=0755 \
    entrypoint.sh claude-agent.sh codex-agent.sh /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
