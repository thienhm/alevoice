# Validation Report

Date: 2026-06-26

## Scope

US-001 benchmark summary reporting for local STT engine comparison.

This report records current Task 5 proof and reserves placeholders for the
future measured benchmark run. No `whisper.cpp` or FunASR benchmark execution
has been performed for this task.

## Commands Run

```text
.venv/bin/python -m pytest tests/benchmarks/test_stt_eval.py::test_summarize_rows_reports_average_latency_per_engine -v
.venv/bin/python -m pytest tests/benchmarks/test_stt_eval.py -v
.venv/bin/python -m pytest tests/benchmarks -v
```

Pending measured-run commands:

```text
python3 tools/benchmarks/run_stt_benchmark.py --engine whispercpp --corpus data/benchmarks/stt_corpus.json
python3 tools/benchmarks/run_stt_benchmark.py --engine funasr --corpus data/benchmarks/stt_corpus.json
python3 tools/benchmarks/summarize_stt_benchmark.py --input-dir tmp/stt-benchmarks
```

## Results

| Check | Result | Notes |
| --- | --- | --- |
| Typecheck | not run | No project typecheck command is defined. |
| Unit | passed | `tests/benchmarks/test_stt_eval.py -v`: 7 passed; `tests/benchmarks -v`: 20 passed. |
| Integration | pending measured run | Engine adapters are not executed in Task 5. |
| E2E | not required | No user-facing flow exists for this story. |
| Platform | pending measured run | Target Mac timing evidence will come from later benchmark execution. |
| Release | pending measured run | Engine recommendation waits for raw results and aggregate summary. |

## Evidence

- Summary module: `tools/benchmarks/summarize_stt_benchmark.py`
- Unit test: `tests/benchmarks/test_stt_eval.py::test_summarize_rows_reports_average_latency_per_engine`
- Pending raw artifacts: `tmp/stt-benchmarks/*.json`
- Pending aggregate command: `python3 tools/benchmarks/summarize_stt_benchmark.py --input-dir tmp/stt-benchmarks`

## Gaps

- Raw benchmark outputs do not exist yet.
- Aggregate report cannot recommend an MVP engine until local measured runs are complete.
- Integration and platform proof remain pending for US-001.
