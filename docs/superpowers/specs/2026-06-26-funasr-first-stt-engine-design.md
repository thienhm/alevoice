# FunASR-First STT Engine Design

## Context

`US-001` benchmarked `whisper.cpp` and FunASR on the same local VI/EN corpus.
The report recommends `whisper.cpp` for MVP by default because FunASR was faster
but did not show material quality improvement across the corpus.

Product direction for the next implementation pass is intentionally different:
build FunASR first, while preserving a clean switch path to `whisper.cpp` if
quality, packaging, stability, or latency blocks the native app.

## Decision

Implement the native app against a pluggable speech engine boundary and set
FunASR as the first default engine.

This does not invalidate the benchmark result. It records a product choice to
try FunASR first despite the conservative benchmark recommendation.

## Goals

- Ship the first native transcription path with FunASR.
- Keep `whisper.cpp` switch cost low.
- Reuse `US-001` corpus and benchmark artifacts as regression proof.
- Avoid coupling native recording, post-processing, overlay, or paste behavior
  to any FunASR-specific runtime detail.

## Non-Goals

- Implement both app engines in the first native slice.
- Re-run engine selection before any native shell work can begin.
- Remove `whisper.cpp` from benchmark evidence or future engine options.
- Treat FunASR as permanently locked.

## Architecture

The native app should depend on a stable speech engine contract:

```text
RecordedAudio
  -> SpeechEngine.transcribe(request)
  -> SpeechTranscriptResult
```

The contract should include:

- audio input path or buffer reference
- language mode: `auto`, `en`, or `vi`
- transcript text
- timing metadata, at least release-to-result latency
- engine name and model identifier for logs/debug output
- error shape that distinguishes setup, runtime, audio format, and empty-result
  failures

Initial backend:

- `FunASREngine`

Reserved backend:

- `WhisperCppEngine`

The app coordinator should know only the selected engine identifier and the
speech engine interface. Model paths, runtime arguments, warmup behavior, and
stdout parsing stay inside the backend implementation.

## Configuration

Default engine:

```text
funasr
```

Engine selection should be centralized in configuration, not scattered through
call sites. A later switch to `whispercpp` should require changing config and
adding the backend implementation, not rewriting recording or insertion flows.

Recommended config fields:

- `engine`: `funasr` or `whispercpp`
- `binary_path`
- `model_path`
- `language_mode_default`
- `warmup_enabled`

## Switch Criteria

Switch from FunASR to `whisper.cpp` if one or more of these hold during native
app validation:

- Vietnamese or mixed VI/EN quality blocks normal dictation.
- Runtime packaging is too fragile for local installation.
- Model loading or transcription crashes during repeated short dictation.
- Warm release-to-result latency regresses beyond acceptable interactive use.
- Empty or malformed transcripts appear often enough to require product-level
  workarounds.

## Validation

For the FunASR-first native slice:

- Unit: engine config parsing, command/request construction, transcript result
  mapping, error mapping.
- Integration: local FunASR transcribes benchmark samples through the same
  native-facing boundary the app will use.
- Platform: target Mac can record a short phrase, send it to FunASR, receive a
  transcript, and preserve engine metadata in logs or debug output.

Before switching to `whisper.cpp`, rerun or reuse `US-001` corpus against both
engines and record the reason for the switch in the story evidence.

## Harness Updates

Next implementation should create a new normal-lane story for the FunASR-first
native transcription slice. That story should link:

- `docs/product/stt-engine-benchmarking.md`
- `docs/stories/epics/E01-local-stt/US-001-benchmark-local-stt-engines.md`
- `docs/validation/us-001-stt-engine-benchmark.md`
- this design spec

If FunASR-first becomes a durable product choice after validation, add a
decision record. Until then, treat it as an implementation strategy with a
clear fallback.
