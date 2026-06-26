# Validation Report

Date: 2026-06-26

## Scope

US-001 benchmark CLI enablement for local STT engine comparison.

This report records current Task 6 proof and reserves placeholders for the
future measured benchmark run. No `whisper.cpp` or FunASR benchmark execution
has been performed for this task.

## Commands Run

```text
.venv/bin/python -m pytest tests/benchmarks/test_stt_eval.py::test_summarize_rows_reports_average_latency_per_engine -v
.venv/bin/python -m pytest tests/benchmarks/test_stt_eval.py -v
.venv/bin/python -m pytest tests/benchmarks -v
.venv/bin/python -m pytest tests/benchmarks/test_stt_eval.py -k "load_engine_config or run_benchmark or write_report" -v
```

Pending measured-run commands:

```text
python3 tools/benchmarks/run_stt_benchmark.py --engine whispercpp --corpus data/benchmarks/stt_corpus.json --config tools/benchmarks/stt_models.json --output-dir tmp/stt-benchmarks
python3 tools/benchmarks/run_stt_benchmark.py --engine funasr --corpus data/benchmarks/stt_corpus.json --config tools/benchmarks/stt_models.json --output-dir tmp/stt-benchmarks
python3 tools/benchmarks/summarize_stt_benchmark.py --input-dir tmp/stt-benchmarks --report docs/validation/us-001-stt-engine-benchmark.md
```

## Results

| Check | Result | Notes |
| --- | --- | --- |
| Typecheck | not run | No project typecheck command is defined. |
| Unit | passed | Targeted CLI helper tests: 3 passed; `tests/benchmarks -v`: 23 passed. |
| Integration | pending measured run | Engine adapters are not executed against local binaries in Task 6. |
| E2E | not required | No user-facing flow exists for this story. |
| Platform | pending measured run | Target Mac timing evidence will come from later benchmark execution. |
| Release | pending measured run | Engine recommendation waits for raw results and aggregate summary. |

## Evidence

- Runner CLI: `tools/benchmarks/run_stt_benchmark.py`
- Summary module CLI: `tools/benchmarks/summarize_stt_benchmark.py`
- Unit tests: `tests/benchmarks/test_stt_eval.py::test_load_engine_config_reads_engine_from_json`,
  `tests/benchmarks/test_stt_eval.py::test_run_benchmark_writes_engine_rows_to_json`,
  `tests/benchmarks/test_stt_eval.py::test_write_report_writes_summary_and_pending_recommendation`
- Pending raw artifacts: `tmp/stt-benchmarks/*.json`
- Pending aggregate command: `python3 tools/benchmarks/summarize_stt_benchmark.py --input-dir tmp/stt-benchmarks --report docs/validation/us-001-stt-engine-benchmark.md`

## Gaps

- `tools/benchmarks/stt_models.json` does not exist yet.
- `whisper-cli` and `funasr-cli` are not available on `PATH` yet.
- Raw benchmark outputs do not exist yet.
- Aggregate report cannot recommend an MVP engine until local measured runs are complete.
- Integration and platform proof remain pending for US-001.
