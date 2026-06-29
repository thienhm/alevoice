# 0008 Manifest-Driven AleVoice Setup CLI

Date: 2026-06-29

## Status

Accepted

## Context

AleVoice is currently distributed as a source-first alpha repository. Users who
clone the repo must manually:

- download the FunASR runtime
- download the model file
- copy the example config
- paste absolute paths into config

That is fragile for onboarding and makes every future engine addition a new
human setup recipe. The setup path also crosses a trust boundary because it
downloads executable and model artifacts from third-party providers.

## Decision

AleVoice setup should move to a manifest-driven CLI flow.

The repository will commit pinned engine manifests under `Config/engines/`.
Each manifest describes:

- stable engine id
- display metadata
- platform-specific runtime artifact URLs
- SHA-256 digests
- unpack behavior
- runtime binary relative path
- model artifact URLs and digests
- default config template values

`AleVoiceCLI` becomes the source-first operational entrypoint for setup and
local verification:

- `setup <engine-id>`
- `doctor`
- `transcribe`
- `run`

The first supported managed engine is `funasr-sensevoice`.

Managed installs live under:

`~/Library/Application Support/AleVoice/`

The app and CLI config contract evolves to support a selected engine plus a map
of installed engines, while remaining backward-compatible with the current
single-engine FunASR config shape during the transition.

## Alternatives Considered

1. Keep manual README-only setup. Rejected because it preserves repeated user
   friction and hides setup logic outside the product surface.
2. Hardcode per-engine installer logic. Rejected because each new engine would
   require more code churn instead of mostly manifest additions.
3. External shell bootstrap scripts. Rejected because they weaken testability
   and split setup trust/control across multiple surfaces.

## Consequences

Positive:

- AleVoice gains a one-command onboarding path for the current alpha flow.
- Future engines can land mostly as manifest additions.
- Checksums become part of the committed setup contract.
- The CLI becomes a stable automation surface for setup and doctor flows.

Tradeoffs:

- The CLI target grows meaningful installer logic and tests.
- External provider artifact drift must be monitored and repinned deliberately.
- Managed install paths and config compatibility need explicit migration logic.

## Follow-Up

- Implement `setup funasr-sensevoice` first.
- Add automated tests for manifest decode, checksum validation, config
  migration, doctor, and setup pipeline failures.
- Consider `setup list`, `config show`, `whispercpp`, and repair/upgrade flows
  in later slices.
