# AleVoice Setup CLI Design

## Goal

Design a one-command AleVoice setup flow that downloads and configures the
speech runtime and model for a selected engine, while staying expandable to
multiple future engines and model layouts.

## Problem

AleVoice currently expects a human to:

- separately obtain a runtime binary
- separately obtain one or more model artifacts
- manually create `Config/speech-engine.json`
- manually paste absolute paths into that config

That is acceptable for local development but too fragile for source-first alpha
distribution through GitHub. It also does not scale cleanly when the project
needs to support engines with different artifact layouts such as:

- one runtime + one model file
- one runtime + several model files
- multiple runtime backends sharing similar UX

## Current State

- `AleVoiceCLI` exists today as a narrow transcription smoke runner:
  - `swift run AleVoiceCLI --config <path> --audio <path> [--mode ...]`
- app config currently supports only the current FunASR path shape:
  - engine kind: `funasr`
  - `binaryPath`
  - `modelPath`
- setup knowledge lives in docs and human memory rather than in the product

## User Outcome

The desired happy path is:

```bash
swift run AleVoiceCLI setup funasr-sensevoice
```

That one command should:

1. choose the right runtime build for the user platform
2. download the runtime and model artifact(s)
3. verify integrity
4. unpack and install them into a stable AleVoice-managed location
5. write AleVoice configuration pointing at those installed artifacts
6. run a health check that confirms the installation is usable

The same setup flow should later support commands like:

```bash
swift run AleVoiceCLI setup whispercpp --model small
swift run AleVoiceCLI setup funasr-nano --variant default
```

## Recommended Approach

Use a manifest-driven installer architecture.

The CLI should implement one generic setup pipeline and feed that pipeline from
versioned engine manifests committed in the repository. Each manifest describes:

- engine id
- supported platforms
- download URLs
- checksums
- unpack behavior
- runtime binary relative path
- model artifact list
- default config values
- optional post-install smoke command inputs

This keeps setup extensible without turning the CLI into a long chain of
engine-specific `switch` statements.

## Alternatives Considered

### 1. Hardcoded per-engine setup subcommands

Example:

```bash
alevoice setup funasr
alevoice setup whispercpp
```

with custom Swift logic for every engine.

Pros:

- fastest to ship for one engine
- fewer initial abstractions

Cons:

- every new engine requires more embedded installer logic
- multi-artifact engines become awkward
- download URLs and checksums become code churn instead of data updates

Verdict: not recommended.

### 2. Manifest-driven generic setup pipeline

Pros:

- one UX for all engines
- supports one-file and multi-file model layouts
- easier version pinning and checksum verification
- future engines usually require data additions more than code changes

Cons:

- slightly more up-front design work
- config model must evolve beyond the current single-engine shape

Verdict: recommended.

### 3. External shell bootstrap scripts

Pros:

- easy to prototype
- can reuse provider docs directly

Cons:

- weak testability
- weak portability
- poor long-term maintainability
- harder to make the CLI the single trusted setup surface

Verdict: not recommended except as temporary exploration tooling.

## CLI Surface

The current CLI should evolve into a subcommand-based tool.

### Commands

```bash
alevoice setup <engine-id> [options]
alevoice setup list
alevoice doctor
alevoice transcribe --audio <path> [--mode auto|en|vi]
alevoice run
alevoice config show
```

### Intended Behavior

#### `setup list`

Prints supported setup targets compiled into the current build, for example:

- `funasr-sensevoice`
- `whispercpp`
- `funasr-nano`

Each entry should include a short description and supported variants if present.

#### `setup <engine-id>`

Main installer/configurator command.

Example:

```bash
alevoice setup funasr-sensevoice
```

Optional future flags:

```bash
--variant <name>
--force-download
--install-root <path>
--config-path <path>
```

Behavior:

1. Load the engine manifest.
2. Resolve current platform.
3. Create install directories if missing.
4. Download runtime archive or binary.
5. Download required model artifact(s).
6. Verify every checksum.
7. Unpack archives when needed.
8. Mark installed runtime executable when required.
9. Write AleVoice config selecting the installed engine.
10. Run a post-install validation pass.
11. Print a concise success summary and next step.

#### `doctor`

Validates local AleVoice readiness. It should be usable independently and also
as the final stage of `setup`.

Checks:

- config file exists and parses
- selected engine exists in config
- configured runtime binary exists
- binary is executable
- required model file(s) exist
- required sample audio exists
- a sample transcription command succeeds when enough data is present
- app bundle build command can run

Future additions may include app permission inspection once a signed app bundle
is present, but those checks are not required for the first setup milestone.

#### `transcribe`

This becomes the renamed and improved version of the current smoke CLI.

Example:

```bash
alevoice transcribe --audio data/benchmarks/samples/en-001.wav
```

By default it should use the selected installed engine from config unless an
override config path is supplied.

#### `run`

Launch the app using the repo-local app launcher script. This keeps the CLI as
the primary user-facing operational surface even while the app remains
source-first.

#### `config show`

Print effective AleVoice engine configuration in a human-readable form.

## Manifest Model

Setup manifests should be committed in the repository and versioned with code.

Recommended location:

```text
Config/engines/
```

Example files:

```text
Config/engines/funasr-sensevoice.json
Config/engines/whispercpp.json
Config/engines/funasr-nano.json
```

### Manifest Responsibilities

A manifest should declare:

- stable engine id
- display name
- description
- supported platforms
- runtime artifact source
- runtime checksum
- runtime unpack type
- runtime executable relative path
- zero or more model artifacts
- per-variant artifact mappings
- config template fields needed by AleVoice
- optional smoke-check defaults

### Example Shape

This example is schema-only. Real implementation manifests must replace the
illustrative URLs and checksums with pinned provider artifacts before any setup
command is shipped.

```json
{
  "id": "funasr-sensevoice",
  "displayName": "FunASR SenseVoice",
  "engineKind": "funasr",
  "defaultVariant": "f16",
  "variants": {
    "f16": {
      "runtime": {
        "platforms": {
          "macos-arm64": {
            "url": "https://example.invalid/runtime-macos-arm64.zip",
            "sha256": "..."
          }
        },
        "unpack": "zip",
        "binaryRelativePath": "llama-funasr-sensevoice"
      },
      "models": [
        {
          "id": "main",
          "url": "https://example.invalid/sensevoice-small-f16.gguf",
          "sha256": "...",
          "relativePath": "sensevoice-small-f16.gguf"
        }
      ],
      "configTemplate": {
        "defaultMode": "auto"
      }
    }
  }
}
```

## Install Layout

The installer should place managed artifacts in an AleVoice-owned directory
rather than leaving them in arbitrary download folders.

Recommended default:

```text
~/Library/Application Support/AleVoice/
```

Proposed structure:

```text
~/Library/Application Support/AleVoice/
  engines/
    funasr-sensevoice/
      current/
        runtime/
        models/
    whispercpp/
      current/
        runtime/
        models/
  cache/
  downloads/
```

Rationale:

- stable location across runs
- not checked into git
- natural place for later upgrades or repair flows
- supports engines with many artifacts

## Config Evolution

Current config is too narrow because it encodes only a single FunASR binary/model
pair. The setup CLI needs a config shape that can represent multiple installed
engines while still selecting one as active.

### Target Config Shape

```json
{
  "selectedEngine": "funasr-sensevoice",
  "engines": {
    "funasr-sensevoice": {
      "engineKind": "funasr",
      "binaryPath": "/Users/me/Library/Application Support/AleVoice/engines/funasr-sensevoice/current/runtime/llama-funasr-sensevoice",
      "modelPath": "/Users/me/Library/Application Support/AleVoice/engines/funasr-sensevoice/current/models/sensevoice-small-f16.gguf",
      "defaultMode": "auto"
    }
  }
}
```

### Compatibility Strategy

The implementation should continue to read the existing config shape during a
transition window, then normalize it into the new in-memory model. That allows:

- existing local setups to keep working
- setup CLI to write the new shape
- future engines to land without another config rewrite

## Engine Support Strategy

### First Target: `funasr-sensevoice`

This is the first full setup target because it matches the current app runtime
path most closely:

- one runtime
- one model
- known current MVP behavior

### Next Target: `whispercpp`

This is the second target because:

- benchmark history already exists in the repository
- artifact layout is still simple
- it exercises the multi-engine config path

### Later Target: `funasr-nano`

This should wait until the manifest and config layers support multi-file engine
payloads cleanly. It is important as a design target now, but it should not
drive the first implementation into unnecessary complexity.

## Error Handling

The setup path must fail loudly and specifically.

Failure classes:

- unsupported platform
- missing manifest
- download failure
- checksum mismatch
- unpack failure
- installed runtime not executable
- config write failure
- doctor failure after install

Every failure should tell the user:

- what step failed
- which artifact or path failed
- whether partial downloads were left behind
- the next recommended recovery action

## Security and Trust

The setup CLI downloads executable and model artifacts, so it must be explicit
about trust boundaries.

Requirements:

- pin artifact URLs in manifests committed to git
- require checksums for all downloaded artifacts
- fail closed on checksum mismatch
- avoid executing freshly downloaded binaries before checksum validation
- keep install root constrained to AleVoice-managed paths by default

Non-goal for first milestone:

- automatic signature validation of third-party runtime binaries

Checksum validation is the minimum required trust control for the initial setup
feature.

## Validation Plan

The first implementation should prove:

- manifest parsing
- platform selection
- download planning
- checksum validation
- config writing
- legacy-config compatibility
- doctor behavior

Suggested proof ladder:

- unit tests for manifest decoding and path planning
- unit tests for config migration and writeback
- unit tests for setup pipeline step ordering and failures
- integration test with fake downloader + fake archive layout
- manual proof for `setup funasr-sensevoice` on macOS arm64

## Non-Goals

- shipping notarized app releases
- auto-updating installed engines
- background download manager behavior
- GUI installer
- hidden implicit model downloads during ordinary app launch

The first setup milestone should remain an explicit CLI-driven install flow.

## Rollout Plan

### Phase 1

- keep current app behavior
- add subcommand CLI shell
- add manifest loader
- add `setup funasr-sensevoice`
- add `doctor`
- add `transcribe` alias/replacement for current smoke runner
- keep `run` as a wrapper around `scripts/run-alevoice-app`

### Phase 2

- add new config shape with compatibility migration
- add `setup list`
- add `config show`
- add `setup whispercpp`

### Phase 3

- add support for engines with multiple model files
- add `setup funasr-nano`
- add engine upgrade and repair affordances if needed

## Recommendation

Implement the setup CLI as a manifest-driven installer with `funasr-sensevoice`
as the first supported engine target. This gives AleVoice the one-command user
experience you want now while preserving a clean path to future engines and
models without recurring CLI redesign.
