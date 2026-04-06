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
ARG GO_VERSION=1.25.7
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
ARG NODE_MAJOR=22
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Workspace ---
RUN mkdir -p /workspace

WORKDIR /workspace
