---
title: Home directory as the durable workspace (image contract)
status: drafted
depends_on: []
affects:
  - base/Dockerfile
  - base/entrypoint (new)
  - gui/entrypoint.sh
  - test.sh
  - README.md
effort: medium
created: 2026-07-13
updated: 2026-07-13
author: changkun
dispatched_task_id: null
---

# Home directory as the durable workspace (image contract)

## Overview

Today the durable-mount contract is `/workspace`: orchestrators mount a
volume there, and everything the agent accumulates in `$HOME` (CLI
session state, npm/pip/go caches, shell history, dotfiles) lives on the
ephemeral container layer and dies with the container. This spec moves
the contract to the whole home directory: orchestrators mount their
volume at `/home/agent`, images seed a fresh home on first boot, and
`/workspace` remains a compatibility symlink so every existing path,
script, and doc keeps working.

This is the image half of the change. What orchestrators mount, how
existing volumes migrate, and quota implications are consumer concerns
and out of scope here.

## Current state

- `base/Dockerfile`: `WORKDIR /workspace`, non-root `agent` (UID 1000),
  home `/home/agent` populated at build time from `/etc/skel` (which
  carries the `CELLA_HOST` prompt patch). No entrypoint (bash).
- `gui/Dockerfile` + `gui/entrypoint.sh` + `gui/vncpass.sh`: GUI
  startup; `provision_vncpass` creates `~/.vncpass` (mode 0600) on
  first boot and never logs the password.
- `harness/Dockerfile`: agent CLIs already installed system-wide
  (`/usr/local`) precisely so a mount over `/home/agent` cannot mask
  them; `~/.claude` and `~/.codex` pre-created.
- A volume mounted at `/home/agent` today hides all of the seeded home:
  the prompt patch, the pre-created CLI state dirs, desktop launchers.

## Design

### seed-home (new, in base)

An idempotent `/usr/local/bin/seed-home` script in the base image:

- If `$HOME/.home-seeded` exists, exit 0.
- Otherwise copy `/etc/skel/.` into `$HOME` (no clobber of files the
  mount already carries), create `$HOME/workspace` and any state dirs
  a child image declares (see below), then write `.home-seeded`.
- Safe to run on every boot, as any user, with or without a mount.

Child images append to the seed by dropping executable snippets into
`/etc/seed-home.d/` (e.g. harness re-creates `~/.claude`/`~/.codex`
with mode 700; gui seeds desktop launchers). `seed-home` sources them
in lexical order after the skel copy.

### Entrypoint wiring

- Base gains `ENTRYPOINT ["/usr/local/bin/base-entry"]`: run
  `seed-home`, then `exec "$@"` (default CMD `bash`). Interactive
  behavior is unchanged for images and callers that override the
  entrypoint, since `seed-home` can also be invoked explicitly by an
  orchestrator's init hook.
- `gui/entrypoint.sh` calls `seed-home` first and keeps its existing
  startup; `provision_vncpass` (sourced from `gui/vncpass.sh`) already
  handles first boot, and the 0600 file is the only channel the
  password is retrievable through.

### /workspace compatibility symlink

`base/Dockerfile` replaces the `/workspace` directory with a symlink to
`/home/agent/workspace` (`seed-home` guarantees the target). `WORKDIR`
stays `/workspace`; resolved through the symlink, every documented
path, user script, and API contract that says `/workspace` keeps
working whether the orchestrator mounts at `/home/agent` (new layout)
or directly at `/workspace`... the latter mounts onto the symlink's
target path only when the runtime resolves it, so consumers moving to
the new layout mount at `/home/agent` and everyone else keeps mounting
a plain directory over the symlink, which container runtimes handle by
replacing it. Both layouts are supported during the transition.

## Acceptance criteria

1. `seed-home` exists in base, is idempotent, and populates an empty
   volume mounted at `/home/agent` with the skel prompt patch, a
   `workspace/` dir, and child-image state dirs via `/etc/seed-home.d/`.
2. Base entrypoint seeds then execs; `docker run ... bash` behaves as
   today when nothing is mounted.
3. `/workspace` resolves to `/home/agent/workspace`; `pwd` in a fresh
   container prints `/workspace`.
4. GUI and harness images seed their home state through
   `/etc/seed-home.d/` snippets instead of build-time-only home writes.
5. test.sh: new checks for the symlink, for seeding into an empty
   mounted home (prompt works, state dirs exist, workspace writable),
   and for idempotency (second boot leaves a marker-stamped home
   untouched).
6. README documents the mount contract: mount at `/home/agent` for a
   durable home, or at `/workspace` for the legacy project-only layout.

## Non-goals

- Orchestrator mount-point changes, volume migration, and quota
  accounting (consumer half).
- Renaming the `agent` user or per-user home paths: the fixed user is
  what keeps images stateless and warm-poolable.

## Verification

1. `podman run -v fresh-volume:/home/agent <base>` boots seeded: prompt
   shows `CELLA_HOST`, `~/workspace` exists and is writable, second run
   with the same volume does not re-copy.
2. Same with the harness image: `claude --version` works and
   `~/.claude` exists with mode 700 on the mounted volume.
3. `podman run -v dir:/workspace <base>` (legacy layout) still lands
   project files where scripts expect them.
4. Full `bash test.sh <tag>` green.

## Rollback

Revert the commits; the previous no-entrypoint base and directory
`/workspace` return on the next release tag.
