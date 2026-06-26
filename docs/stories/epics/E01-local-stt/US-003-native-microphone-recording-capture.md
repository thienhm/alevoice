# US-003 Native Microphone Recording Capture

## Status

implemented

## Lane

normal

## Product Contract

Native macOS debug shell can capture short microphone audio locally, persist it
as engine-ready audio, and pass that captured clip through existing FunASR-first
transcription core without changing language-mode semantics.

## Relevant Product Docs

- `docs/superpowers/specs/2026-06-25-local-stt-dictation-design.md`
- `docs/product/stt-engine-benchmarking.md`
- `docs/stories/epics/E01-local-stt/US-002-funasr-first-native-transcription-core.md`
- `docs/superpowers/specs/2026-06-26-funasr-first-stt-engine-design.md`

## Acceptance Criteria

- Reusable native audio-capture boundary exists in Swift and writes a temporary
  WAV file suitable for current speech-engine flow.
- Debug UI can start and stop microphone capture, then transcribe recorded audio
  through existing coordinator using same explicit language-mode contract.
- Microphone permission denial, capture failure, and empty recording states are
  surfaced as user-visible errors instead of silent no-ops.
- Story proof shows target Mac can record a short phrase and render transcript
  plus latency from microphone-captured audio.
- Design keeps future hotkey, overlay, formatting, and paste automation work
  outside capture implementation.

## Design Notes

- Commands: start capture, stop capture, then transcribe saved audio file.
- Queries: current capture state, latest transcript, latest latency, latest
  user-visible error.
- API: no network API; local AVFoundation boundary only.
- Tables: no app database tables in this slice.
- Domain rules:
  - FunASR-first path stays default.
  - Explicit language mode remains `auto`, `en`, or `vi`; unsupported explicit
    mode must still fail loudly at engine boundary.
  - Recorder owns audio session, file creation, and stop/finalize lifecycle.
  - Transcription flow consumes recorded file through existing coordinator.
- UI surfaces:
  - native SwiftUI debug shell with record/stop control
  - retained sample transcription action for deterministic smoke proof

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id <id> --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Swift tests cover recorder state transitions, view-model behavior, and error surfacing. |
| Integration | Shared transcription path accepts recorder-produced audio file and preserves explicit mode handling. |
| E2E | Not required for this slice; no global hotkey or paste automation yet. |
| Platform | Target Mac app records a short microphone clip and shows transcript plus latency in native UI. |
| Release | Validation note records commands, manual capture proof, microphone-permission assumptions, and known follow-ups. |

## Harness Delta

- Add story packet and durable story row for first real microphone-input slice.
- Preserve explicit language-mode contract while moving from static sample audio
  to recorded input.

## Evidence

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed with 38 tests, 0 failures.
- `.venv/bin/python -m pytest tests/benchmarks -v` passed with 24 tests, 0 failures.
- `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto` printed:
  - `engine=funasr`
  - `latency_ms=380`
  - `open terminal and show get status`
- Native app proof on target Mac shell:
  - visible `AleVoiceApp` process exposed record/stop/sample controls through accessibility tree
  - clicking sample button rendered:
    - `379 ms`
    - `open terminal and show get status`
  - clicking start capture changed status text to `Recording in progress`
  - stopping silent capture surfaced `emptyTranscript` instead of silently succeeding
- `docs/validation/us-003-native-microphone-recording-capture.md`
