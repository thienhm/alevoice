# US-005 Configurable Global Hotkey And Input Monitoring

## Status

planned

## Lane

normal

## Product Contract

Native macOS debug shell lets user record a persisted dictation shortcut, shows
Input Monitoring status, and uses shortcut hold/release lifecycle to drive the
existing microphone recording and transcription path.

## Relevant Product Docs

- `docs/product/local-dictation-workflow.md`
- `docs/product/stt-engine-benchmarking.md`
- `docs/superpowers/specs/2026-06-26-configurable-global-hotkey-design.md`
- `docs/stories/epics/E01-local-stt/US-004-reliable-native-app-shell-and-permissions.md`

## Acceptance Criteria

- User can record shortcut in UI and see human-readable persisted value.
- Shortcut must include at least one modifier.
- Input Monitoring state is visible and refreshable in UI.
- Global shortcut activation starts recording once.
- Shortcut release stops recording and transcribes once.
- Existing manual recorder controls still work.
- No paste, overlay, or formatting behavior is added in this slice.

## Design Notes

- Commands: record shortcut, refresh/request Input Monitoring, start recording,
  stop recording and transcribe.
- Queries: current shortcut, capture-mode state, Input Monitoring state,
  recording state, latest transcript, latest latency, latest error.
- API: no network API.
- Tables: no app database tables.
- Domain rules:
  - shortcut requires at least one modifier
  - bare character keys are rejected
  - release of any required key ends recording
  - capture mode must suppress live dictation trigger
- UI surfaces:
  - native SwiftUI debug shell
  - shortcut capture row
  - Input Monitoring row

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-005 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Shortcut modeling, persistence, and state-machine tests pass. |
| Integration | Debug view model applies captured shortcut and routes release to existing transcription path. |
| E2E | Not required for this slice; no paste automation or overlay yet. |
| Platform | Configured shortcut starts and stops recording globally on target Mac after Input Monitoring approval. |
| Release | Validation report records commands, platform proof, and known shortcut limitations. |

## Harness Delta

- Add first product doc for non-benchmark dictation workflow.
- Add story packet and validation note for configurable shortcut slice.

## Evidence

Add commands, screenshots, and manual proof after implementation.
