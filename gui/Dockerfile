ARG BASE_IMAGE=sandbox-base:latest
FROM ${BASE_IMAGE}

USER root

# GUI stack for future Cella computer-use sandboxes. The VNC server is
# bound to localhost inside the container; orchestration proxies it.
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    x11vnc \
    mutter \
    dbus-x11 \
    xdotool \
    x11-utils \
    x11-apps \
    imagemagick \
    fonts-dejavu \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    python3-websockify \
    novnc \
    ca-certificates \
    curl \
    tini \
    unzip \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2t64 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Chrome for Testing is the automation-grade Chromium build used by
# computer-use stacks. Pin the version so image rebuilds are reproducible.
ARG CFT_VERSION=128.0.6613.119
ARG TARGETARCH
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64) cft_arch=linux64 ;; \
        *) echo "Chrome for Testing Linux archives are only available for amd64; build this image for linux/amd64" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://storage.googleapis.com/chrome-for-testing-public/${CFT_VERSION}/${cft_arch}/chrome-${cft_arch}.zip" -o /tmp/chrome.zip; \
    unzip -q /tmp/chrome.zip -d /opt; \
    mv "/opt/chrome-${cft_arch}" /opt/chromium; \
    rm /tmp/chrome.zip; \
    ln -s /opt/chromium/chrome /usr/local/bin/chromium; \
    find /opt/chromium/locales -name '*.pak' ! -name 'en-US.pak' -delete

ARG USERNAME=gui
ARG USER_UID=1000
ARG USER_GID=1000
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true && \
    groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chown ${USERNAME}:${USERNAME} /workspace

COPY --chmod=0755 entrypoint.sh /usr/local/bin/gui-entrypoint
COPY --chmod=0755 supervisor.sh /usr/local/bin/gui-supervisor
COPY --chmod=0755 chromium-launch /usr/local/bin/chromium-launch

USER ${USERNAME}
ENV DISPLAY=:0
ENV SCREEN_GEOMETRY=1280x800x24
ENV NOVNC_PORT=6080
EXPOSE 6080

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/gui-entrypoint"]
