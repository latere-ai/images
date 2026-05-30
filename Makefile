SHELL   := /bin/bash
RUNTIME := podman

BASE_IMAGE         := sandbox-base:latest
BASE_GHCR_IMAGE    := ghcr.io/latere-ai/sandbox-base:latest
GUI_IMAGE          := sandbox-gui:latest
GUI_GHCR_IMAGE     := ghcr.io/latere-ai/sandbox-gui:latest

.PHONY: all base gui clean

all: gui

base:
	$(RUNTIME) build -t $(BASE_IMAGE) -t $(BASE_GHCR_IMAGE) -f base/Dockerfile base/

gui: base
	$(RUNTIME) build --build-arg BASE_IMAGE=$(BASE_IMAGE) \
		-t $(GUI_IMAGE) -t $(GUI_GHCR_IMAGE) -f gui/Dockerfile gui/

clean:
	-$(RUNTIME) rmi $(GUI_IMAGE) $(GUI_GHCR_IMAGE) \
		$(BASE_IMAGE) $(BASE_GHCR_IMAGE)
