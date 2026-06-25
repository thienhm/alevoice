# US-001 Benchmark Local STT Engines

## Status

planned

## Lane

normal

## Product Contract

Create local benchmark harness that compares only `whisper.cpp` and FunASR for
short VI/EN dictation on target Mac, then produce evidence strong enough to
pick MVP engine before native app work starts.

## Relevant Product Docs

- `docs/product/stt-engine-benchmarking.md`
- `docs/superpowers/specs/2026-06-25-local-stt-dictation-design.md`

## Acceptance Criteria

- Benchmark corpus exists with labeled English, Vietnamese, mixed VI/EN, and
  formatting-command samples.
- Harness can run both `whisper.cpp` and FunASR against same corpus and record
  structured outputs.
- Results include per-sample latency and transcript evidence for both engines.
- Aggregate report recommends one engine for MVP and names known weak spots.
- Story proof explains what remains before native macOS shell story can start.

## Design Notes

- Commands: benchmark runner executes corpus against one or both engines and
  writes JSON/CSV results plus markdown summary.
- Queries: result aggregation reads structured benchmark output and computes
  rollups by engine and sample category.
- API: no network API; local CLI and file inputs only.
- Tables: no app database tables; durable Harness story row tracks proof state.
- Domain rules:
  - same corpus and evaluation rubric for both engines
  - `auto`, `en`, and `vi` mode expectations must be explicit per sample
  - warm latency is primary timing metric
  - benchmark code must stay decoupled from later macOS UI shell
- UI surfaces: none for MVP benchmark; terminal commands and markdown reports
  only.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id <id> --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Corpus loader, transcript normalizer, and score calculator tests pass. |
| Integration | Each engine adapter runs on local sample set and emits structured result file. |
| E2E | Not required; no user-facing flow yet. |
| Platform | Target Mac benchmark run records timing and recommendation evidence. |
| Release | Markdown summary and raw result artifacts exist for engine lock review. |

## Harness Delta

- Create first story packet and durable story row for local STT work.
- Add benchmark behavior to `docs/TEST_MATRIX.md`.
- Record benchmark friction if local engine setup or model packaging causes
  repeated manual work.

## Evidence

Planned benchmark commands and artifacts:

- `python3 tools/benchmarks/run_stt_benchmark.py --engine whispercpp --corpus data/benchmarks/stt_corpus.json`
- `python3 tools/benchmarks/run_stt_benchmark.py --engine funasr --corpus data/benchmarks/stt_corpus.json`
- `python3 tools/benchmarks/summarize_stt_benchmark.py --input-dir tmp/stt-benchmarks`
- `tmp/stt-benchmarks/*.json`
- `docs/validation/us-001-stt-engine-benchmark.md`
