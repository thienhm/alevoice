# Design

## Domain Model

Add a manifest-driven setup model in the CLI target:

- `SetupManifest`: pinned engine metadata committed in `Config/engines/`
- `SetupVariantManifest`: variant-scoped runtime/model payloads
- `SetupArtifact`: URL, checksum, relative install path, optional unpack mode
- `InstallLayout`: AleVoice-managed directories for downloads, runtime, models,
  and generated config
- `DoctorCheckResult`: named readiness checks with pass/fail detail

Keep `SpeechEngineSettings` as the app/core contract, but evolve it to support:

- `selectedEngine`
- keyed `engines`
- legacy single-engine FunASR decode compatibility

The first supported managed engine remains `funasr` under the stable id
`funasr-sensevoice`.

## Application Flow

`AleVoiceCLI` becomes a subcommand runner with four phase-1 commands:

1. `setup <engine-id>`
2. `doctor`
3. `transcribe`
4. `run`

Setup flow:

1. Parse subcommand and optional path flags.
2. Load the pinned manifest from `Config/engines/<engine-id>.json`.
3. Resolve the current platform target.
4. Create AleVoice install directories under
   `~/Library/Application Support/AleVoice/`.
5. Download runtime and model artifacts into a managed download/cache area.
6. Verify SHA-256 digests before install.
7. Unpack the runtime archive into the managed runtime directory.
8. Move/copy model artifacts into the managed model directory.
9. Mark the runtime executable when required.
10. Write the new config shape to the selected config path.
11. Run doctor checks.

Doctor flow:

- load config
- resolve selected engine
- verify binary path, executable bit, model path, sample audio, and optional
  sample transcription when all local inputs exist

Transcribe flow:

- keep the current smoke behavior but move it under `transcribe`
- support legacy root flags for a transition window by treating
  `--config ... --audio ...` as `transcribe`

Run flow:

- shell out to `scripts/run-alevoice-app`

## Interface Contract

CLI contract:

- `AleVoiceCLI setup funasr-sensevoice [--config-path <path>] [--install-root <path>] [--force-download]`
- `AleVoiceCLI doctor [--config-path <path>]`
- `AleVoiceCLI transcribe [--config <path>] --audio <path> [--mode auto|en|vi]`
- `AleVoiceCLI run`

Failure output must identify:

- failing phase
- relevant artifact or path
- recovery direction

The app still reads `Config/speech-engine.json` by default, so setup writes to
that repo-local path unless the caller overrides it.

## Data Model

No database schema changes.

Harness durable changes:

- new high-risk story `US-008`
- updated story proof row after validation
- detailed trace for external download/config workflow work

## UI / Platform Impact

- No UI redesign in this slice.
- The app setup workflow changes from manual config editing to CLI-driven setup.
- `DebugAssetLocator` should continue to find the repo-local config written by
  setup for source-first alpha runs.

## Observability

- `setup`, `doctor`, and `transcribe` should print concise step/result output.
- Harness records should capture the pinned provider artifacts and validation
  commands used in this slice.

## Alternatives Considered

1. Hardcode installer logic in one large `main.swift` switch. Rejected because
   it makes future engine additions code-heavy and weakly testable.
2. Keep manual README-only setup. Rejected because it preserves avoidable user
   friction and does not scale to more than one engine.
