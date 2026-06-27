# Validation

## Proof Strategy

This story is complete only when automated tests cover the new formatting and
session-state behavior, the app behaves as a resident menu bar utility in local
platform use, the overlay appears during dictation states, and focused-app paste
proof is recorded in updated validation notes.

## Test Plan

| Layer | Cases |
| --- | --- |
| Unit | `TranscriptFormatter` English and Vietnamese commands, normal text preservation, Auto-only recording path, session-state transitions |
| Integration | Recording transcripts are formatted before paste, sample transcription remains display-only, menu/overlay state adapters reflect view-model state |
| E2E | Not required as a separate automated layer for this local macOS MVP |
| Platform | Menu bar launch, open settings window, global shortcut recording, overlay feedback, TextEdit plus Notes or browser paste proof |
| Performance | Existing local latency display remains intact; no new performance target is introduced in this slice |
| Logs/Audit | Story evidence, validation note, matrix row, and trace are updated |

## Fixtures

- Existing sample audio under `data/benchmarks/samples/`
- Existing local FunASR config under `Config/`
- TextEdit and either Notes or a browser text field for focused paste proof

## Commands

Expected commands:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path
rtk ./scripts/bin/harness-cli story verify US-007
```

## Acceptance Evidence

Record these exact results during verification:

- automated test pass result
- observed menu bar behavior
- observed overlay behavior
- focused TextEdit paste proof
- second focused field paste proof
