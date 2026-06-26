# US-002 Build FunASR-First Native Transcription Core

## Status

planned

## Lane

normal

## Product Contract

Create first native macOS transcription slice that runs local FunASR through a
pluggable speech engine boundary and returns transcript text plus latency
metadata without coupling app flow to FunASR-specific process details.

## Relevant Product Docs

- `docs/superpowers/specs/2026-06-25-local-stt-dictation-design.md`
- `docs/product/stt-engine-benchmarking.md`
- `docs/stories/epics/E01-local-stt/US-001-benchmark-local-stt-engines.md`
- `docs/superpowers/specs/2026-06-26-funasr-first-stt-engine-design.md`

## Acceptance Criteria

- Native Swift project exists with a reusable `SpeechEngine` boundary and
  centralized engine configuration.
- FunASR backend shells out to configured local runtime and returns transcript,
  engine name, model identifier, and latency metadata.
- Minimal smoke surfaces exist for same core flow: one CLI entrypoint and one
  small native debug UI.
- Story proof shows FunASR can transcribe at least one benchmark sample through
  native-facing code on target Mac.
- Design keeps later `whisper.cpp` switch limited to configuration and backend
  addition rather than app-flow rewrite.

## Design Notes

- Commands: load engine settings, run FunASR process, surface transcript
  through CLI and debug UI.
- Queries: read current engine selection and recent transcription result state.
- API: no network API; local process boundary only.
- Tables: no app database tables in this slice.
- Domain rules:
  - selected engine defaults to `funasr`
  - language mode stays explicit: `auto`, `en`, or `vi`
  - engine backend owns stdout parsing and runtime flags
  - transcript result must carry latency and engine metadata
- UI surfaces:
  - minimal SwiftUI debug shell
  - CLI smoke runner

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id <id> --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Swift tests cover config loading, engine command construction, transcript parsing, and coordinator/view model behavior. |
| Integration | CLI smoke runner transcribes benchmark sample through FunASR backend using local config. |
| E2E | Not required for this slice; no global hotkey or paste automation yet. |
| Platform | Target Mac launches native debug UI and shows transcript plus latency from FunASR-backed request. |
| Release | Validation note records commands, sample used, config shape, and known switch triggers. |

## Harness Delta

- Add first native STT story packet after benchmark-only `US-001`.
- Preserve benchmark corpus as regression input for future engine switch checks.
- Record fallback reason if `whisper.cpp` becomes necessary during validation.

## Evidence

Planned validation commands:

- `swift test`
- `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
- Native debug shell launch plus screenshot/log evidence

