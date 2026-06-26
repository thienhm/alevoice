# US-004 Validation Report

## Summary

Native debug shell launch stability and microphone permission visibility are
validated separately from recorder/transcription behavior. Recorder start/stop
and FunASR transcription remain the US-003 path.

## Commands Run

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `.venv/bin/python -m pytest tests/benchmarks -v`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode en`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/run-alevoice-app --print-bundle-path`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/run-alevoice-app`
- `osascript -l JavaScript` accessibility probes against the launched
  `AleVoiceApp` window controls and status text

## Results

- Swift test suite passed with 45 tests and 0 failures.
- Benchmark harness regression suite passed with 24 tests and 0 failures.
- CLI auto-mode smoke remained:
  - `engine=funasr`
  - `latency_ms=347`
  - `open terminal and show get status`
- CLI explicit English mode still failed loudly with:
  - `invalidConfiguration("funasr runtime does not support explicit language mode 'en'")`
- Launcher print-path command built and reported:
  - `/Users/alex/workspace/Projects/alevoice/.build/debug/AleVoiceApp.app`
- Bundle verification showed:
  - copied executable at `Contents/MacOS/AleVoiceApp`
  - bundle identifier `dev.alevoice.AleVoiceApp`
  - ad-hoc signature
  - `NSMicrophoneUsageDescription` in `Info.plist`

## Platform Proof

- Repeated app-bundle launch through `./scripts/run-alevoice-app` created a
  visible `AleVoiceApp` process with one native window.
- Initial accessible UI text included:
  - `Microphone permission: not determined`
  - `Recorder idle`
- Bundled sample action resolved repo assets from LaunchServices cwd and
  rendered:
  - `425 ms`
  - `open terminal and show get status`
- Live microphone start action changed status text to:
  - `Recording in progress`
- Live microphone stop action completed real recorder/transcription path and
  rendered:
  - `Microphone permission: authorized`
  - `Last recording ready`
  - `268 ms`
  - `now let's give black a piece`

## Known Limits

- Live microphone transcript content depends on ambient spoken input and is not
  asserted as stable product text. Stable regression proof still comes from
  recorder unit tests, view-model tests, bundled sample transcription, and CLI
  sample smoke.
- This slice intentionally does not add global hotkey capture, overlay UI,
  paste automation, or formatting-command handling.
