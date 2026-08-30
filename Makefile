SHELL   := /bin/bash
RUNTIME := podman

# Image inventory lives in catalog.yaml; targets are the context dirs
# (make base, make gui). catalog.sh resolves FROM chains and tags each
# image as <name>:latest and <registry>/<name>:latest.
CONTEXTS := $(shell yq -r '.images[].context' catalog.yaml)

.PHONY: all test clean hooks $(CONTEXTS)

all:
	RUNTIME=$(RUNTIME) ./catalog.sh build

$(CONTEXTS):
	RUNTIME=$(RUNTIME) ./catalog.sh build $@

test:
	bash catalog_test.sh

clean:
	RUNTIME=$(RUNTIME) ./catalog.sh clean

# hooks points git at the repository hook directory and restores the local
# CLAUDE.md -> AGENTS.md symlink, which is gitignored and so absent in a fresh
# clone.
hooks:
	git config core.hooksPath .githooks
	@[ -e CLAUDE.md ] || [ -L CLAUDE.md ] || ln -s AGENTS.md CLAUDE.md
	@echo "installed git hooks (core.hooksPath=.githooks)"
