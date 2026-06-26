# US-004 Reliable Native App Shell And Permissions

## Status

implemented

## Lane

normal

## Product Contract

Native macOS debug shell launches reliably from a local command, shows current
microphone permission state in UI, and preserves existing US-003 recorder and
transcription behavior.

## Relevant Product Docs

- `docs/superpowers/specs/2026-06-25-local-stt-dictation-design.md`
- `docs/product/stt-engine-benchmarking.md`
- `docs/stories/epics/E01-local-stt/US-002-funasr-first-native-transcription-core.md`
- `docs/stories/epics/E01-local-stt/US-003-native-microphone-recording-capture.md`

## Acceptance Criteria

- App launches consistently as a native macOS debug shell from a local command.
- Microphone permission state is detectable and shown in UI.
- Recorder start/stop can be validated with a real mic path or a documented
  blocker.
- US-003 recorder/transcription behavior remains unchanged.
- No hotkey, overlay, paste, or formatting work is added in this slice.

## Design Notes

- Commands: build native app bundle, launch native shell, refresh microphone
  permission state, start recording, stop recording, transcribe recorded file.
- Queries: current microphone permission state, current recording state, latest
  transcript, latest latency, latest user-visible error.
- API: no network API; local native shell and AVFoundation boundary only.
- Tables: no app database tables in this slice.
- Domain rules:
  - FunASR-first path stays default.
  - Explicit language mode remains `auto`, `en`, or `vi`; unsupported explicit
    mode must still fail loudly at engine boundary.
  - Permission state visibility is additive; it must not change recorder start,
    stop, or transcription semantics.
  - Native launch stabilization must focus on local shell packaging, not new app
    features.
- UI surfaces:
  - native SwiftUI debug shell with permission status text
  - existing sample and microphone controls

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id <id> --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Swift tests cover permission-state mapping plus view-model permission refresh behavior. |
| Integration | CLI sample transcription still passes through existing FunASR-first path unchanged. |
| E2E | Not required for this slice; no hotkey, overlay, paste, or formatting work. |
| Platform | Local launcher command opens native debug shell, permission state is visible, and recorder start/stop is validated with live mic proof or a documented blocker. |
| Release | Validation note records launch command, verification commands, permission-state UI proof, and remaining platform blockers if any. |

## Harness Delta

- Add explicit proof surface for native-shell launch stability and permission
  visibility without widening scope beyond recorder debugging.
- Preserve US-003 evidence and make launch instability a tracked validation
  concern instead of an implied shell quirk.

## Evidence

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed with
  45 tests and 0 failures.
- `.venv/bin/python -m pytest tests/benchmarks -v` passed with 24 tests and 0
  failures.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
  printed:
  - `engine=funasr`
  - `latency_ms=347`
  - `open terminal and show get status`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode en`
  still failed loudly with
  `invalidConfiguration("funasr runtime does not support explicit language mode 'en'")`.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/run-alevoice-app --print-bundle-path`
  built `.build/debug/AleVoiceApp.app` with copied executable, stable bundle id,
  ad-hoc signature, and `NSMicrophoneUsageDescription`.
- Native app proof through accessibility scripting after launcher open:
  - initial UI showed `Microphone permission: not determined`
  - sample action rendered `425 ms` and `open terminal and show get status`
  - live microphone start changed status to `Recording in progress`
  - live microphone stop changed permission text to `authorized`, status to
    `Last recording ready`, latency to `268 ms`, and transcript to
    `now let's give black a piece`
- `docs/validation/us-004-reliable-native-app-shell-and-permissions.md`
