# Overview

## Current Behavior

AleVoice currently expects a local developer to obtain the FunASR runtime and
model manually, copy `Config/speech-engine.example.json`, edit absolute paths by
hand, then run the app or the narrow smoke CLI against that config.

The app and CLI both read only the current single-engine config shape:

- top-level `engine`
- `funasr.binaryPath`
- `funasr.modelPath`
- `funasr.defaultMode`

This keeps existing development unblocked, but it is fragile for GitHub-first
alpha onboarding and does not scale cleanly to future engines.

## Target Behavior

AleVoice should offer a one-command setup path for the first supported managed
engine:

- `swift run AleVoiceCLI setup funasr-sensevoice`

That command should download pinned provider artifacts, verify checksums,
install them under AleVoice-managed application-support paths, write AleVoice
config selecting the installed engine, and finish with a readiness check.

The repo should continue to support:

- app launch through `./scripts/run-alevoice-app`
- CLI transcription through `AleVoiceCLI transcribe`
- legacy local configs that still use the current single-engine FunASR shape

## Affected Users

- Alpha users cloning AleVoice from GitHub and expecting a one-command local
  setup path.
- Developers validating local STT and app behavior without hand-editing binary
  or model paths.

## Affected Product Docs

- `docs/product/local-dictation-workflow.md`
- `README.md`
- `docs/superpowers/specs/2026-06-29-setup-cli-design.md`

## Non-Goals

- Bundling third-party runtime/model artifacts inside the app bundle.
- Supporting multiple engines in the first shipped setup slice.
- Adding macOS permission inspection to doctor.
