SHELL   := /bin/bash
RUNTIME := podman

BASE_IMAGE         := sandbox-base:latest
BASE_GHCR_IMAGE    := ghcr.io/latere-ai/sandbox-base:latest
CLAUDE_IMAGE       := sandbox-claude:latest
CLAUDE_GHCR_IMAGE  := ghcr.io/latere-ai/sandbox-claude:latest
CODEX_IMAGE        := sandbox-codex:latest
CODEX_GHCR_IMAGE   := ghcr.io/latere-ai/sandbox-codex:latest
AGENTS_IMAGE       := sandbox-agents:latest
AGENTS_GHCR_IMAGE  := ghcr.io/latere-ai/sandbox-agents:latest

.PHONY: all base claude codex agents clean

all: claude codex agents

base:
	$(RUNTIME) build -t $(BASE_IMAGE) -t $(BASE_GHCR_IMAGE) -f base/Dockerfile base/

claude: base
	$(RUNTIME) build --build-arg BASE_IMAGE=$(BASE_IMAGE) \
		-t $(CLAUDE_IMAGE) -t $(CLAUDE_GHCR_IMAGE) -f claude/Dockerfile claude/

codex: base
	$(RUNTIME) build --build-arg BASE_IMAGE=$(BASE_IMAGE) \
		-t $(CODEX_IMAGE) -t $(CODEX_GHCR_IMAGE) -f codex/Dockerfile codex/

agents: base
	$(RUNTIME) build --build-arg BASE_IMAGE=$(BASE_IMAGE) \
		-t $(AGENTS_IMAGE) -t $(AGENTS_GHCR_IMAGE) -f agents/Dockerfile agents/

clean:
	-$(RUNTIME) rmi $(CLAUDE_IMAGE) $(CLAUDE_GHCR_IMAGE) \
		$(CODEX_IMAGE) $(CODEX_GHCR_IMAGE) \
		$(AGENTS_IMAGE) $(AGENTS_GHCR_IMAGE) \
		$(BASE_IMAGE) $(BASE_GHCR_IMAGE)
