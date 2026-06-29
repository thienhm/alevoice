# US-009 Multi-Engine Language Selection

## Status

implemented

## Lane

normal

## Product Contract

AleVoice can install multiple managed local FunASR engines side-by-side, let the
user select the active model and a supported language mode, and route real
hotkey dictation through that selected model/mode.

## Relevant Product Docs

- `docs/product/local-dictation-workflow.md`
- `README.md`
- `docs/superpowers/specs/2026-06-29-multi-engine-language-selection-design.md`

## Acceptance Criteria

- `setup funasr-sensevoice` and `setup funasr-nano` can both be represented in
  the same `Config/speech-engine.json`.
- Engine config records selected engine, selected mode, display name, supported
  modes, and Nano's auxiliary encoder model path.
- Settings UI exposes model and language pickers, and language options are
  filtered by the selected engine.
- Manual recording and global hotkey release use the selected language mode
  instead of hardcoded Auto.
- CLI help documents multi-engine setup and `auto|en|vi` mode vocabulary.
  Installed engine metadata still decides which of those modes appears.
- Explicit language modes remain capability-gated by installed engine metadata.

## Design Notes

- Commands: `AleVoiceCLI setup funasr-sensevoice`, `AleVoiceCLI setup funasr-nano`,
  `AleVoiceCLI setup funasr-mlt-nano`, `AleVoiceCLI transcribe --mode auto|en|vi`.
- Domain rules: selected mode must be listed in the selected engine's
  `supportedModes`; SenseVoice remains Auto-only by config; pinned Nano
  declares `auto` and `en`; MLT Nano declares `auto`, `en`, and `vi`.
- UI surfaces: settings/debug window model picker and language picker.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-009 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Config decode/validation, manifest decode, installer merge, command building, view-model mode filtering. |
| Integration | Full Swift test suite, CLI help smoke, doctor missing-config clarity. |
| E2E | Not required for this slice. |
| Platform | Real `setup funasr-mlt-nano` download/runtime smoke on macOS. |
| Release | README and product contract updated. |

## Harness Delta

- Added this story after implementation because the request was normal-lane
  behavior with user-visible workflow changes.

## Evidence

2026-06-29:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
  passed with 133 tests and 0 failures.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI --help`
  showed `setup funasr-sensevoice`, `setup funasr-nano`,
  `setup funasr-mlt-nano`, and `--mode auto|en|vi`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI doctor`
  failed cleanly because local `Config/speech-engine.json` is absent in the
  worktree.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI setup funasr-mlt-nano --config-path /tmp/alevoice-mlt-proof/config.json --install-root /tmp/alevoice-mlt-proof/install`
  installed CrispASR v0.8.5 plus `funasr-mlt-nano-2512-q8_0.gguf`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI transcribe --config /tmp/alevoice-mlt-proof/config.json --audio data/benchmarks/samples/vi-001.wav --mode vi`
  returned `Mở terminal và hiển thị giúp status.`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI transcribe --config /tmp/alevoice-mlt-proof/config.json --audio data/benchmarks/samples/en-001.wav --mode en`
  returned `Open terminal and show git status.`
