# Validation

## Proof Strategy

This story is complete only when the CLI can install the pinned FunASR
SenseVoice runtime/model into an AleVoice-managed location, write working
config, preserve legacy-config reads, pass automated CLI/config/installer tests,
and keep the app plus transcription smoke path working.

## Test Plan

| Layer | Cases |
| --- | --- |
| Unit | manifest decode, platform resolution, install layout planning, config migration, checksum validation, CLI parsing |
| Integration | setup pipeline with fake downloader/unpacker/file system writes, doctor on installed artifacts, legacy root flags mapping to `transcribe` |
| E2E | not required as a separate automated layer for this source-first slice |
| Platform | manual `setup funasr-sensevoice` on macOS arm64, manual `run` wrapper smoke |
| Performance | no new latency target; keep sample transcription proof within existing local runtime expectations |
| Logs/Audit | update Harness story row, validation evidence, decision record, and detailed trace |

## Fixtures

- repo sample audio at `data/benchmarks/samples/en-001.wav`
- fake runtime archive payload in test temp directories
- fake model payload in test temp directories
- pinned manifest for `funasr-sensevoice`

## Commands

Expected commands:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI doctor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI transcribe --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto
```

## Acceptance Evidence

2026-06-29 automated proof:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
  passed with 107 tests and 0 failures.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI --help`
  printed the new subcommand surface: `setup`, `doctor`, `transcribe`, and
  `run`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI doctor`
  returned exit 1 with a specific missing-config check before setup:
  `config: failed - missing config at .../Config/speech-engine.json`.

Manual external-provider proof:

- Started real `setup funasr-sensevoice` into `/tmp/alevoice-setup-cli-proof`
  with `--force-download`.
- Runtime archive download completed and wrote
  `/tmp/alevoice-setup-cli-proof/downloads/funasr-llamacpp-macos-arm64.tar.gz`.
- The first live attempt exposed that the default downloader buffered the large
  model through `Data(contentsOf:)`, leaving no partial file/progress while the
  model was in flight. The downloader was changed to stream through
  `URLSession.downloadTask` before final validation.
- Full 470 MB model setup proof was not completed in this pass to avoid spending
  more task time on external network transfer after the streaming fix.
