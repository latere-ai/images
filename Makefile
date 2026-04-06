SHELL   := /bin/bash
RUNTIME := podman

CLAUDE_IMAGE       := sandbox-claude:latest
CLAUDE_GHCR_IMAGE  := ghcr.io/latere-ai/sandbox-claude:latest
CODEX_IMAGE        := sandbox-codex:latest
CODEX_GHCR_IMAGE   := ghcr.io/latere-ai/sandbox-codex:latest

.PHONY: all claude codex clean

all: claude codex

claude:
	$(RUNTIME) build -t $(CLAUDE_IMAGE) -t $(CLAUDE_GHCR_IMAGE) -f claude/Dockerfile claude/

codex:
	$(RUNTIME) build -t $(CODEX_IMAGE) -t $(CODEX_GHCR_IMAGE) -f codex/Dockerfile codex/

clean:
	-$(RUNTIME) rmi $(CLAUDE_IMAGE) $(CLAUDE_GHCR_IMAGE) $(CODEX_IMAGE) $(CODEX_GHCR_IMAGE)
