# STT Engine Benchmarking

## Goal

Select local speech-to-text engine for macOS dictation MVP by comparing only
`whisper.cpp` and FunASR on target machine.

## Scope

This benchmark phase exists to answer one product question before native app
implementation starts:

- Which engine gives better real VI/EN dictation results on target Mac within
  acceptable release-to-result latency?

Out of scope for this phase:

- global hotkey capture
- microphone permission UX
- overlay UI
- clipboard paste automation
- cross-app text insertion

## Benchmark Contract

Benchmark work must:

- run fully local on target macOS machine
- compare only `whisper.cpp` and FunASR
- use same prompt corpus shape for both engines
- measure warm latency after audio capture completes
- score English, Vietnamese, mixed-language, and formatting-command utterances
- produce durable evidence that supports engine choice for MVP

## Prompt Corpus Requirements

Corpus must include short dictation-style utterances that match intended use:

- English prompt dictation
- Vietnamese prompt dictation
- code-switched VI/EN utterances
- punctuation and newline command phrases

Each sample needs:

- stable sample id
- reference transcript
- language mode expectation: `auto`, `en`, or `vi`
- category label for rollup reporting

## Decision Rule

Default engine choice should prefer `whisper.cpp` unless FunASR shows material
improvement on target machine across both of these:

- recognition quality for real prompt-style dictation
- warm release-to-result latency

If results split, preserve both adapters in benchmark harness and record why
MVP picked one engine over other.

## Required Evidence

Before engine lock, benchmark output must include:

- per-sample transcript results for both engines
- latency measurements for each run
- aggregate summary by engine and corpus category
- written recommendation with noted failure cases
