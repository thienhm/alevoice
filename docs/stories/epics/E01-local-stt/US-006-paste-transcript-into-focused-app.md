# US-006 Paste Transcript Into Focused App

## Status

implemented

## Lane

normal

## Product Contract

After a successful dictation transcription, the native macOS app inserts the
transcript into the currently focused text input by using clipboard-backed
paste automation.

## Relevant Product Docs

- `docs/product/local-dictation-workflow.md`
- `docs/superpowers/specs/2026-06-25-local-stt-dictation-design.md`
- `docs/stories/epics/E01-local-stt/US-005-configurable-global-hotkey-and-input-monitoring.md`

## Acceptance Criteria

- Successful manual or global-hotkey recording transcription sends the final
  transcript to a focused-app paste output boundary.
- Failed transcription, empty transcript, failed recording, or shortcut capture
  mode must not paste anything.
- Sample-audio debug transcription remains display-only and does not paste.
- Paste automation uses the clipboard and simulates `Cmd+V`.
- Accessibility status is visible and requestable from the debug UI.
- Paste failures surface as visible errors without clearing the transcript.
- Clipboard preservation is best-effort for plain string contents in this
  slice.
- Overlay UI and formatting-command normalization are covered by `US-007`.

## Design Notes

- Commands: refresh/request Accessibility, stop recording and transcribe,
  deliver transcript to focused app.
- Queries: Accessibility status, recording state, latest transcript, latest
  latency, latest error.
- API: no network API.
- Tables: no app database tables.
- Domain rules:
  - only successful recording transcription can paste
  - sample transcription never pastes
  - empty or whitespace-only transcript is not delivered
  - output errors do not erase the latest transcript
- UI surfaces:
  - native SwiftUI debug shell
  - Accessibility permission row

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-006 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Transcript output service tests pass. |
| Integration | Debug view model calls paste output after successful recording transcription and skips paste for sample or failure paths. |
| E2E | Not required for this slice; overlay and formatting remain out of scope. |
| Platform | Manual local proof in a focused text input after Accessibility approval. |
| Release | Validation report records automated commands, manual paste proof, and clipboard limitations. |

## Harness Delta

- Add story packet and validation note for clipboard-backed paste automation.

## Evidence

2026-06-27: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test` passed with 78 tests and 0 failures. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path` built, ad-hoc signed, and reported `.build/debug/AleVoiceApp.app`. Automated coverage now includes `TranscriptOutputServiceTests`, `ClipboardPasteTranscriptOutputTests`, and updated debug view-model tests proving that successful recording transcription routes through paste output, sample transcription stays display-only, and output failures keep the transcript visible while surfacing an error.

App wiring now exposes an `Accessibility: <status>` row with refresh/request actions, and successful recording transcription delegates to a clipboard-backed `Cmd+V` output adapter.

2026-06-27 menu bar MVP follow-up: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test` passed with 87 tests and 0 failures after adding Auto-only formatted recording delivery. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path` built, ad-hoc signed, and reported `.build/debug/AleVoiceApp.app`. Local inspection confirmed the app runs as a background/accessory process and the menu bar settings window reports `Accessibility: not determined` for the rebuilt ad-hoc bundle. Final app-driven focused-field paste proof still requires granting Accessibility permission to `dev.alevoice.AleVoiceApp`.

2026-06-27 validation closeout follow-up: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test` passed with 94 tests and 0 failures, `rtk ./scripts/bin/harness-cli story verify US-007` passed, System Events confirmed the live `.build/arm64-apple-macosx/debug/AleVoiceApp.app/Contents/MacOS/AleVoiceApp` process is a background-only resident app with a `waveform` status menu, and opening `AleVoice Settings` showed `Microphone permission: not determined`, `Accessibility: not determined`, and `Input Monitoring: not determined`. Final focused-field paste proof still requires granting at least Microphone and Accessibility to `dev.alevoice.AleVoiceApp`, then rerunning live recording/paste validation.
