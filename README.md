# Sandbox Images

Container images for the Cella sandbox platform.

## Images

- **sandbox-base**: shared base image with OS packages, Go, Go tools, Node.js, Python, and a non-root `agent` user
  `ghcr.io/latere-ai/sandbox-base`
- **sandbox-gui**: base + GUI/VNC stack for computer-use workflows
  `ghcr.io/latere-ai/sandbox-gui`

## What's inside

The base image (Ubuntu 24.04, multi-arch amd64/arm64) provides:

- **OS**: Ubuntu 24.04 with `build-essential`, `git`, `curl`, `wget`, `vim`, `jq`, `ripgrep`, `openssh-client`
- **Go**: 1.25.7 + tooling (gopls, goimports, delve, golangci-lint, staticcheck, gosec, and more)
- **Node.js**: 22 LTS
- **Python**: 3 with pip and venv
- **Non-root user**: `agent` (UID 1000), passwordless sudo

Image-specific additions:

- **sandbox-gui**
  - Xvfb display, mutter window manager, x11vnc, websockify/noVNC, xdotool, ImageMagick, and Chrome for Testing
  - Exposes noVNC on port `6080` and defaults to `SCREEN_GEOMETRY=1280x800x24`

## Using pre-built images

Pre-built images are published to GHCR on every release:

```bash
# Pull the base image
podman pull ghcr.io/latere-ai/sandbox-base:latest

# Pull a specific version
podman pull ghcr.io/latere-ai/sandbox-base:v0.0.1

# Pull the GUI variant
podman pull ghcr.io/latere-ai/sandbox-gui:latest
```

Replace `podman` with `docker` if using Docker.

## Building locally

```bash
git clone https://github.com/latere-ai/images.git
cd images

make            # Build all images (base, gui)
make base       # Build base image only
make gui        # Build GUI/VNC sandbox (builds base first)
make clean      # Remove all images
```

Override the container runtime (default: `podman`):

```bash
make RUNTIME=docker
```

Built images are tagged as both `sandbox-base:latest` (local) and `ghcr.io/latere-ai/sandbox-base:latest` (registry name).

## Running standalone

You can run these images directly. Mount a workspace directory into the container under `/workspace`.

### Base sandbox

```bash
docker run --rm -it \
  -v "$(pwd)":/workspace/myproject \
  -w /workspace/myproject \
  ghcr.io/latere-ai/sandbox-base:latest \
  bash
```

The container runs as the non-root `agent` user with `/home/agent` as `$HOME`. Install any agent CLI you need inside the sandbox (e.g. `npm install -g <cli>`).

### GUI sandbox

`sandbox-gui` is an image for computer-use workflows. It starts an Xvfb display, a lightweight window manager, x11vnc, and a noVNC websocket bridge.

The GUI image is published for `linux/amd64` because Chrome for Testing does not ship a Linux arm64 archive. On arm64 hosts, run it with `--platform linux/amd64`.

Run it locally and open noVNC:

```bash
docker run --rm -it \
  --platform linux/amd64 \
  -p 6080:6080 \
  -v "$(pwd)":/workspace/myproject \
  -w /workspace/myproject \
  ghcr.io/latere-ai/sandbox-gui:latest
```

Then visit `http://localhost:6080/vnc.html`. The entrypoint creates `~/.vncpass` on first boot and prints the generated password to stderr for standalone use. Set `VNC_PASSWORD` or replace that file when orchestration owns attach credentials.

Launch Chromium inside the display:

```bash
docker run --rm -it \
  --platform linux/amd64 \
  -p 6080:6080 \
  ghcr.io/latere-ai/sandbox-gui:latest \
  chromium-launch https://example.com
```

### Notes

- Replace `docker` with `podman` if preferred.
- Mount additional project directories as needed under `/workspace/`.
- To limit resources: `--cpus 2 --memory 4g`.

## Image contract

These details are relevant if you are building custom images on top of the sandboxes or integrating them into your own orchestration.

- **Working directory**: `/workspace` (workspaces are mounted as subdirectories)
- **User**: non-root `agent` (UID 1000), passwordless sudo, `$HOME=/home/agent`
- **Prompt**: the shell prompt prefers the `CELLA_HOST` env var (the runtime-injected instance name) and falls back to the kernel hostname when unset
- **GUI mode**: `sandbox-gui` starts its own display on `DISPLAY=:0` and serves noVNC from port `6080`; override `SCREEN_GEOMETRY` to change the boot-time display size
