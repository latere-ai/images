SHELL   := /bin/bash
RUNTIME := podman

# Image inventory lives in catalog.yaml; targets are the context dirs
# (make base, make gui). catalog.sh resolves FROM chains and tags each
# image as <name>:latest and <registry>/<name>:latest.
CONTEXTS := $(shell yq -r '.images[].context' catalog.yaml)

.PHONY: all test clean $(CONTEXTS)

all:
	RUNTIME=$(RUNTIME) ./catalog.sh build

$(CONTEXTS):
	RUNTIME=$(RUNTIME) ./catalog.sh build $@

test:
	sh catalog_test.sh

clean:
	RUNTIME=$(RUNTIME) ./catalog.sh clean
