ARG BASE_IMAGE=sandbox-base:latest
FROM ${BASE_IMAGE}

# --- Non-root user ---
ARG USERNAME=claude
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
ENV PATH=$PATH:/home/${USERNAME}/go/bin

# --- RTK (token-optimized CLI proxy) ---
ARG RTK_VERSION=0.34.2
RUN RTK_VERSION=${RTK_VERSION} \
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

# --- Claude Code CLI ---
RUN npm install -g @anthropic-ai/claude-code

# --- Entrypoint ---
COPY --chown=${USERNAME}:${USERNAME} entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
