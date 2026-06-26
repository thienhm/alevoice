# US-002 Validation Report

## Summary

FunASR-backed native transcription core works through shared Swift boundary.

## Commands

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
- `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode en`
- `swift run AleVoiceApp`
- AppleScript accessibility click/poll:
  - `click button 1 of group 1 of window 1`
  - `get value of every static text of group 1 of window 1`

## Evidence

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed with 24 tests and 0 failures across `AleVoiceCoreTests` and `AleVoiceAppUITests`.
- `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto` printed:
  - `engine=funasr`
  - `latency_ms=478`
  - `open terminal and show get status`
- `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode en` fails with `invalidConfiguration("funasr runtime does not support explicit language mode 'en'")`, so explicit mode is surfaced as unsupported instead of ignored.
- `swift run AleVoiceApp` built and launched successfully. After an accessibility click on `Transcribe en-001 sample`, visible UI text included:
  - `366 ms`
  - `open terminal and show get status`
- Runtime config stayed centralized in local ignored file `Config/speech-engine.json`, populated from `tools/benchmarks/stt_models.json` FunASR paths.

## Known Limits

- No microphone capture yet.
- No global hotkey or paste automation yet.
- `whisper.cpp` backend not added in app code yet; switch path remains architectural only.
- Current local `llama-funasr-sensevoice --help` usage exposes no language-override flag, so FunASR default mode is restricted to `auto` and explicit `en`/`vi` requests fail fast with configuration error.
