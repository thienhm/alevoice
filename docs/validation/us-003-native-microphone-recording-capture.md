# US-003 Validation Report

## Summary

Native debug shell can start and stop microphone capture through a reusable
Swift recorder boundary, then route captured audio through existing FunASR-first
transcription flow while keeping explicit language-mode behavior unchanged.

## Commands Run

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `.venv/bin/python -m pytest tests/benchmarks -v`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --target AleVoiceApp`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer .build/debug/AleVoiceApp`
- `osascript` accessibility probes against `AleVoiceApp` window controls and
  status text

## Results

- `swift test` passed with 38 tests, 0 failures.
- Benchmark harness regression suite passed with 24 tests, 0 failures.
- CLI smoke output remained:
  - `engine=funasr`
  - `latency_ms=380`
  - `open terminal and show get status`
- Recorder unit tests now cover:
  - permission denial
  - concurrent start rejection
  - finalize cleanup
  - empty recording cleanup
  - coordinator explicit-mode handoff from recorder-produced file URL
- Debug view model tests now cover:
  - start-recording state
  - stop-and-transcribe with explicit language mode
  - permission-denied error surfacing
  - empty-recording error surfacing
- Native debug shell evidence from accessibility scripting:
  - app exposed segmented language picker, start button, stop button, and sample button
  - sample action rendered `379 ms` and `open terminal and show get status`
  - microphone start action changed status text to `Recording in progress`
  - stopping a silent capture surfaced `emptyTranscript`

## Known Limits

- Current automation run did not produce a spoken microphone transcript; shell
  environment had no reliable spoken-input source, so platform proof captured
  start/stop/error surfacing but not a successful live dictation phrase.
- Repeated raw SwiftPM executable launches were flaky under shell automation:
  one run exposed full accessible window state, later relaunches sometimes left
  a visible process with no window. Story keeps UI code unchanged from the run
  that produced successful accessible controls, but future packaging work should
  revisit app-launch stability outside `swift run`/raw executable shells.
- FunASR explicit language overrides remain unsupported by current local
  runtime; recorder path does not bypass that guard.
