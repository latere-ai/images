FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# --- System packages ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    wget \
    vim \
    jq \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    openssh-client \
    sudo \
    locales \
    ripgrep \
    python3 \
    python3-pip \
    python3-venv \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# --- Go ---
ARG GO_VERSION=1.26.4
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
    | tar -C /usr/local -xzf - && \
    ln -s /usr/local/go/bin/go /usr/local/bin/go && \
    ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# --- Go tools ---
# Major tools are pinned to specific versions for reproducibility.
# Utility tools use @latest (stable, rarely breaking).
ARG GOPLS_VERSION=v0.21.1
ARG DLV_VERSION=v1.24.2
ARG GOLANGCI_LINT_VERSION=v2.11.3
ENV GOPATH=/root/go
ENV PATH=$PATH:/root/go/bin
RUN go install golang.org/x/tools/gopls@${GOPLS_VERSION} && \
    go install golang.org/x/tools/cmd/goimports@latest && \
    go install golang.org/x/tools/cmd/gorename@latest && \
    go install golang.org/x/tools/cmd/godoc@latest && \
    go install github.com/go-delve/delve/cmd/dlv@${DLV_VERSION} && \
    go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@${GOLANGCI_LINT_VERSION} && \
    go install honnef.co/go/tools/cmd/staticcheck@latest && \
    go install github.com/fatih/gomodifytags@latest && \
    go install github.com/josharian/impl@latest && \
    go install github.com/cweill/gotests/gotests@latest && \
    go install github.com/rogpeppe/godef@latest && \
    go install github.com/ramya-rao-a/go-outline@latest && \
    go install github.com/securego/gosec/v2/cmd/gosec@latest && \
    rm -rf /root/go/pkg /root/.cache/go-build
# Move tools to /usr/local so they are available to all users
RUN cp /root/go/bin/* /usr/local/bin/ && rm -rf /root/go
ENV GOPATH=
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# --- Node.js 22 LTS ---
# Install Node.js from a signed apt source instead of piping a remote setup
# script into bash. The signing key is vendored in this context rather than
# fetched at build time: downloading it from deb.nodesource.com would trust
# the same host whose packages it is meant to verify, so a compromise there
# would serve both a substituted key and packages signed with it. Reviewing
# the key means reviewing nodesource.gpg.key in git. The build asserts the
# primary fingerprint so an edit to that file cannot swap the trust anchor
# unnoticed, and signed-by scopes the keyring to this source alone.
ARG NODE_MAJOR=22
ARG NODE_KEY_FPR=6F71F525282841EEDAF851B42F59B5F99B1BE0B4
COPY nodesource.gpg.key /tmp/nodesource.gpg.key
RUN gpg --show-keys --with-colons --with-fingerprint /tmp/nodesource.gpg.key \
        | awk -F: '$1 == "fpr" { print $10; exit }' \
        | grep -qx "${NODE_KEY_FPR}" \
        || { echo "nodesource.gpg.key does not match NODE_KEY_FPR" >&2; exit 1; } && \
    gpg --dearmor -o /usr/share/keyrings/nodesource.gpg /tmp/nodesource.gpg.key && \
    rm /tmp/nodesource.gpg.key && \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Interactive prompt: instance-aware hostname ---
# The sandbox runtime injects CELLA_HOST into each interactive session
# with the human-friendly instance name. A pooled container keeps the
# kernel hostname it was created with (immutable on a running
# container), so rewrite the stock PS1 to prefer CELLA_HOST and fall
# back to \h when it is unset. Patched in /etc/skel so users created by
# child images (useradd -m) inherit it, plus root and the default user
# already materialized from skel. Build fails if the base ever stops
# shipping a \h prompt, so this cannot silently regress.
RUN set -eu; patched=0; \
    for rc in /etc/skel/.bashrc /root/.bashrc /home/ubuntu/.bashrc; do \
        [ -f "$rc" ] || continue; \
        if ! grep -q 'CELLA_HOST' "$rc" && grep -q '\\h' "$rc"; then \
            sed -i 's/\\h/${CELLA_HOST:-\\h}/g' "$rc"; \
        fi; \
        grep -q 'CELLA_HOST' "$rc" && patched=$((patched+1)) || true; \
    done; \
    [ "$patched" -gt 0 ] || { echo 'base .bashrc had no \h prompt to patch' >&2; exit 1; }

# --- Non-root user ---
# Every sandbox runs as a single non-root user (UID 1000) with passwordless
# sudo. The user is created after the skel patch above so its $HOME/.bashrc is
# materialized from the patched /etc/skel. Child images (e.g. gui) inherit this
# user instead of recreating it.
ARG USERNAME=agent
ARG USER_UID=1000
ARG USER_GID=1000
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true && \
    groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    mkdir -p /workspace && \
    chown ${USERNAME}:${USERNAME} /workspace

USER ${USERNAME}
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global
ENV PATH=$PATH:/home/${USERNAME}/.npm-global/bin
WORKDIR /workspace
