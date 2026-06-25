# STT Engine Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build local benchmark harness that compares `whisper.cpp` and FunASR on same VI/EN dictation corpus and produces evidence to lock MVP engine.

**Architecture:** Keep benchmark work separate from future macOS app shell. Use Python 3 scripts for corpus loading, adapter orchestration, latency measurement, and report generation, while each engine stays behind small CLI-facing adapter interface. Store corpus, raw results, and summary artifacts in explicit repo paths so later stories can inspect and reuse benchmark evidence.

**Tech Stack:** Python 3.14, local CLI binaries for `whisper.cpp` and FunASR runtime, JSON corpus files, markdown validation report, Harness CLI durable story tracking.

---

## File Structure

- Create `data/benchmarks/stt_corpus.json` for labeled prompt corpus.
- Create `tools/benchmarks/stt_models.example.json` for local model and binary path configuration.
- Create `tools/benchmarks/stt_benchmark_types.py` for typed benchmark record shapes.
- Create `tools/benchmarks/stt_corpus.py` for corpus parsing and validation.
- Create `tools/benchmarks/stt_eval.py` for normalization, latency stats, and transcript scoring helpers.
- Create `tools/benchmarks/stt_engine_base.py` for shared engine adapter protocol.
- Create `tools/benchmarks/stt_engine_whispercpp.py` for `whisper.cpp` adapter.
- Create `tools/benchmarks/stt_engine_funasr.py` for FunASR adapter.
- Create `tools/benchmarks/run_stt_benchmark.py` for per-engine benchmark execution.
- Create `tools/benchmarks/summarize_stt_benchmark.py` for aggregate report output.
- Create `tests/benchmarks/test_stt_corpus.py` for corpus validation tests.
- Create `tests/benchmarks/test_stt_eval.py` for normalization and score tests.
- Create `docs/validation/us-001-stt-engine-benchmark.md` for benchmark evidence write-up.
- Modify `docs/stories/epics/E01-local-stt/US-001-benchmark-local-stt-engines.md` only if acceptance criteria or evidence paths change during implementation.

### Task 1: Seed Corpus And Config Surface

**Files:**
- Create: `data/benchmarks/stt_corpus.json`
- Create: `tools/benchmarks/stt_models.example.json`
- Test: `tests/benchmarks/test_stt_corpus.py`

- [ ] **Step 1: Write failing corpus validation test**

```python
from tools.benchmarks.stt_corpus import load_corpus


def test_load_corpus_rejects_missing_category(tmp_path):
    corpus_path = tmp_path / "bad.json"
    corpus_path.write_text(
        """
        [
          {
            "id": "en-001",
            "audio_path": "samples/en-001.wav",
            "reference": "hello world",
            "mode": "auto"
          }
        ]
        """.strip(),
        encoding="utf-8",
    )

    try:
        load_corpus(corpus_path)
    except ValueError as exc:
        assert "category" in str(exc)
    else:
        raise AssertionError("expected ValueError")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/benchmarks/test_stt_corpus.py::test_load_corpus_rejects_missing_category -v`
Expected: FAIL with `ModuleNotFoundError` or missing `load_corpus` implementation.

- [ ] **Step 3: Write minimal corpus loader and seed corpus/config files**

```python
# tools/benchmarks/stt_corpus.py
from __future__ import annotations

import json
from pathlib import Path


REQUIRED_KEYS = {"id", "audio_path", "reference", "mode", "category"}


def load_corpus(path: Path) -> list[dict[str, str]]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    for row in rows:
        missing = REQUIRED_KEYS - row.keys()
        if missing:
            raise ValueError(f"missing required keys: {sorted(missing)}")
    return rows
```

```json
[
  {
    "id": "en-001",
    "audio_path": "samples/en-001.wav",
    "reference": "open terminal and show git status",
    "mode": "auto",
    "category": "english"
  },
  {
    "id": "vi-001",
    "audio_path": "samples/vi-001.wav",
    "reference": "mo terminal va hien thi git status",
    "mode": "auto",
    "category": "vietnamese"
  }
]
```

```json
{
  "whispercpp": {
    "binary": "/absolute/path/to/whisper-cli",
    "model": "/absolute/path/to/ggml-model.bin"
  },
  "funasr": {
    "binary": "/absolute/path/to/funasr-cli",
    "model": "/absolute/path/to/funasr-gguf-model"
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/benchmarks/test_stt_corpus.py::test_load_corpus_rejects_missing_category -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add data/benchmarks/stt_corpus.json tools/benchmarks/stt_corpus.py tools/benchmarks/stt_models.example.json tests/benchmarks/test_stt_corpus.py
git commit -m "feat: add benchmark corpus definition"
```

### Task 2: Add Typed Records And Evaluation Helpers

**Files:**
- Create: `tools/benchmarks/stt_benchmark_types.py`
- Create: `tools/benchmarks/stt_eval.py`
- Test: `tests/benchmarks/test_stt_eval.py`

- [ ] **Step 1: Write failing normalization and scoring tests**

```python
from tools.benchmarks.stt_eval import normalize_text, score_transcript


def test_normalize_text_collapses_spacing_and_case():
    assert normalize_text("  Xin   Chao  ") == "xin chao"


def test_score_transcript_returns_exact_match_for_identical_text():
    score = score_transcript("new line", "new line")
    assert score.exact_match is True
    assert score.reference_tokens == 2
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m pytest tests/benchmarks/test_stt_eval.py -v`
Expected: FAIL with missing module or missing functions.

- [ ] **Step 3: Write minimal evaluation helpers**

```python
# tools/benchmarks/stt_eval.py
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class TranscriptScore:
    exact_match: bool
    reference_tokens: int
    hypothesis_tokens: int


def normalize_text(text: str) -> str:
    return " ".join(text.casefold().split())


def score_transcript(reference: str, hypothesis: str) -> TranscriptScore:
    ref_norm = normalize_text(reference)
    hyp_norm = normalize_text(hypothesis)
    return TranscriptScore(
        exact_match=ref_norm == hyp_norm,
        reference_tokens=len(ref_norm.split()) if ref_norm else 0,
        hypothesis_tokens=len(hyp_norm.split()) if hyp_norm else 0,
    )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/benchmarks/test_stt_eval.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/benchmarks/stt_benchmark_types.py tools/benchmarks/stt_eval.py tests/benchmarks/test_stt_eval.py
git commit -m "feat: add benchmark evaluation helpers"
```

### Task 3: Define Engine Adapter Boundary

**Files:**
- Create: `tools/benchmarks/stt_engine_base.py`
- Create: `tools/benchmarks/stt_engine_whispercpp.py`
- Create: `tools/benchmarks/stt_engine_funasr.py`
- Test: `tests/benchmarks/test_stt_corpus.py`

- [ ] **Step 1: Extend tests to assert adapter config parsing**

```python
from tools.benchmarks.stt_engine_base import EngineConfig


def test_engine_config_requires_binary_and_model_paths():
    config = EngineConfig(name="whispercpp", binary="/tmp/whisper", model="/tmp/model.bin")
    assert config.name == "whispercpp"
    assert config.binary.endswith("whisper")
```

- [ ] **Step 2: Run targeted tests to verify failure**

Run: `python3 -m pytest tests/benchmarks/test_stt_corpus.py -v`
Expected: FAIL with missing `EngineConfig` definition.

- [ ] **Step 3: Write adapter protocol and stubs**

```python
# tools/benchmarks/stt_engine_base.py
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Protocol


@dataclass(frozen=True)
class EngineConfig:
    name: str
    binary: str
    model: str


@dataclass(frozen=True)
class EngineResult:
    transcript: str
    latency_ms: int


class SpeechBenchmarkEngine(Protocol):
    config: EngineConfig

    def transcribe(self, audio_path: Path, mode: str) -> EngineResult: ...
```

```python
# tools/benchmarks/stt_engine_whispercpp.py
from __future__ import annotations

from pathlib import Path

from tools.benchmarks.stt_engine_base import EngineConfig


class WhisperCppEngine:
    def __init__(self, config: EngineConfig) -> None:
        self.config = config

    def build_command(self, audio_path: Path, mode: str) -> list[str]:
        language_args = [] if mode == "auto" else ["--language", mode]
        return [self.config.binary, "--model", self.config.model, "--file", str(audio_path), *language_args]
```

```python
# tools/benchmarks/stt_engine_funasr.py
from __future__ import annotations

from pathlib import Path

from tools.benchmarks.stt_engine_base import EngineConfig


class FunASREngine:
    def __init__(self, config: EngineConfig) -> None:
        self.config = config

    def build_command(self, audio_path: Path, mode: str) -> list[str]:
        mode_args = [] if mode == "auto" else ["--language", mode]
        return [self.config.binary, "--model", self.config.model, "--audio", str(audio_path), *mode_args]
```

- [ ] **Step 4: Re-run tests to verify they pass**

Run: `python3 -m pytest tests/benchmarks/test_stt_corpus.py -v`
Expected: PASS for config and command-building tests.

- [ ] **Step 5: Commit**

```bash
git add tools/benchmarks/stt_engine_base.py tools/benchmarks/stt_engine_whispercpp.py tools/benchmarks/stt_engine_funasr.py tests/benchmarks/test_stt_corpus.py
git commit -m "feat: define stt engine adapter boundary"
```

### Task 4: Implement Per-Engine Benchmark Runner

**Files:**
- Create: `tools/benchmarks/run_stt_benchmark.py`
- Modify: `tools/benchmarks/stt_engine_whispercpp.py`
- Modify: `tools/benchmarks/stt_engine_funasr.py`
- Modify: `tools/benchmarks/stt_eval.py`
- Test: `tests/benchmarks/test_stt_eval.py`

- [ ] **Step 1: Write failing runner smoke test**

```python
from tools.benchmarks.run_stt_benchmark import benchmark_sample
from tools.benchmarks.stt_engine_base import EngineConfig, EngineResult


class FakeEngine:
    def __init__(self):
        self.config = EngineConfig(name="fake", binary="fake", model="fake")

    def transcribe(self, audio_path, mode):
        return EngineResult(transcript="hello", latency_ms=123)


def test_benchmark_sample_records_engine_name_and_exact_match(tmp_path):
    sample = {
        "id": "en-001",
        "audio_path": str(tmp_path / "sample.wav"),
        "reference": "hello",
        "mode": "auto",
        "category": "english",
    }
    row = benchmark_sample(FakeEngine(), sample)
    assert row["engine"] == "fake"
    assert row["exact_match"] is True
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/benchmarks/test_stt_eval.py::test_benchmark_sample_records_engine_name_and_exact_match -v`
Expected: FAIL with missing benchmark runner.

- [ ] **Step 3: Implement runner and CLI-backed adapter calls**

```python
# tools/benchmarks/run_stt_benchmark.py
from __future__ import annotations

from pathlib import Path

from tools.benchmarks.stt_eval import score_transcript


def benchmark_sample(engine, sample: dict[str, str]) -> dict[str, object]:
    result = engine.transcribe(Path(sample["audio_path"]), sample["mode"])
    score = score_transcript(sample["reference"], result.transcript)
    return {
        "sample_id": sample["id"],
        "engine": engine.config.name,
        "category": sample["category"],
        "mode": sample["mode"],
        "reference": sample["reference"],
        "transcript": result.transcript,
        "latency_ms": result.latency_ms,
        "exact_match": score.exact_match,
    }
```

```python
# inside each engine adapter
import subprocess
import time

from tools.benchmarks.stt_engine_base import EngineResult


def parse_transcript(stdout: str) -> str:
    return stdout.strip()


def transcribe(self, audio_path: Path, mode: str) -> EngineResult:
    command = self.build_command(audio_path, mode)
    started = time.perf_counter()
    completed = subprocess.run(command, capture_output=True, text=True, check=True)
    elapsed_ms = int((time.perf_counter() - started) * 1000)
    return EngineResult(transcript=parse_transcript(completed.stdout), latency_ms=elapsed_ms)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/benchmarks/test_stt_eval.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/benchmarks/run_stt_benchmark.py tools/benchmarks/stt_engine_whispercpp.py tools/benchmarks/stt_engine_funasr.py tools/benchmarks/stt_eval.py tests/benchmarks/test_stt_eval.py
git commit -m "feat: add per-engine benchmark runner"
```

### Task 5: Add Summary Report And Validation Artifact

**Files:**
- Create: `tools/benchmarks/summarize_stt_benchmark.py`
- Create: `docs/validation/us-001-stt-engine-benchmark.md`
- Modify: `docs/stories/epics/E01-local-stt/US-001-benchmark-local-stt-engines.md`
- Test: `tests/benchmarks/test_stt_eval.py`

- [ ] **Step 1: Write failing summary test**

```python
from tools.benchmarks.summarize_stt_benchmark import summarize_rows


def test_summarize_rows_reports_average_latency_per_engine():
    rows = [
        {"engine": "whispercpp", "latency_ms": 1000, "exact_match": True, "category": "english"},
        {"engine": "whispercpp", "latency_ms": 1200, "exact_match": False, "category": "english"},
    ]
    summary = summarize_rows(rows)
    assert summary["whispercpp"]["avg_latency_ms"] == 1100
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/benchmarks/test_stt_eval.py::test_summarize_rows_reports_average_latency_per_engine -v`
Expected: FAIL with missing summarizer.

- [ ] **Step 3: Implement summarizer and draft validation report**

```python
def summarize_rows(rows: list[dict[str, object]]) -> dict[str, dict[str, float]]:
    grouped: dict[str, list[dict[str, object]]] = {}
    for row in rows:
        grouped.setdefault(str(row["engine"]), []).append(row)

    return {
        engine: {
            "avg_latency_ms": sum(int(item["latency_ms"]) for item in items) / len(items),
            "exact_match_rate": sum(1 for item in items if item["exact_match"]) / len(items),
        }
        for engine, items in grouped.items()
    }
```

```md
# US-001 Validation Report

## Environment
- machine: pending measured benchmark run
- macOS: pending measured benchmark run
- corpus version: `data/benchmarks/stt_corpus.json`

## Commands
- `python3 tools/benchmarks/run_stt_benchmark.py --engine whispercpp --corpus data/benchmarks/stt_corpus.json`
- `python3 tools/benchmarks/run_stt_benchmark.py --engine funasr --corpus data/benchmarks/stt_corpus.json`
- `python3 tools/benchmarks/summarize_stt_benchmark.py --input-dir tmp/stt-benchmarks`

## Recommendation
- selected engine: pending measured benchmark run
- why: pending comparison of aggregate latency and transcript evidence
- known weak cases: pending per-sample review
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/benchmarks/test_stt_eval.py -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/benchmarks/summarize_stt_benchmark.py docs/validation/us-001-stt-engine-benchmark.md docs/stories/epics/E01-local-stt/US-001-benchmark-local-stt-engines.md tests/benchmarks/test_stt_eval.py
git commit -m "feat: add stt benchmark summary reporting"
```

### Task 6: Run Benchmark Proof And Close Story Loop

**Files:**
- Modify: `docs/validation/us-001-stt-engine-benchmark.md`
- Modify: `docs/stories/epics/E01-local-stt/US-001-benchmark-local-stt-engines.md`
- Modify: `docs/TEST_MATRIX.md`

- [ ] **Step 1: Run unit and integration checks**

Run: `python3 -m pytest tests/benchmarks -v`
Expected: PASS

- [ ] **Step 2: Run benchmark against `whisper.cpp`**

Run: `python3 tools/benchmarks/run_stt_benchmark.py --engine whispercpp --corpus data/benchmarks/stt_corpus.json --config tools/benchmarks/stt_models.json --output-dir tmp/stt-benchmarks`
Expected: JSON result file created under `tmp/stt-benchmarks/`.

- [ ] **Step 3: Run benchmark against FunASR**

Run: `python3 tools/benchmarks/run_stt_benchmark.py --engine funasr --corpus data/benchmarks/stt_corpus.json --config tools/benchmarks/stt_models.json --output-dir tmp/stt-benchmarks`
Expected: JSON result file created under `tmp/stt-benchmarks/`.

- [ ] **Step 4: Generate summary and write recommendation**

Run: `python3 tools/benchmarks/summarize_stt_benchmark.py --input-dir tmp/stt-benchmarks --report docs/validation/us-001-stt-engine-benchmark.md`
Expected: report updated with aggregate metrics, recommendation, and weak cases.

- [ ] **Step 5: Update Harness proof and commit**

```bash
scripts/bin/harness-cli story update --id US-001 --status implemented --unit 1 --integration 1 --e2e 0 --platform 1
git add docs/validation/us-001-stt-engine-benchmark.md docs/stories/epics/E01-local-stt/US-001-benchmark-local-stt-engines.md docs/TEST_MATRIX.md tmp/stt-benchmarks
git commit -m "feat: benchmark local stt engines"
```

## Self-Review

- Spec coverage: plan covers corpus creation, engine adapters, benchmark execution, summary report, and final MVP engine recommendation. Native macOS shell work remains intentionally out of scope.
- Placeholder scan: code-facing tasks include concrete files, commands, and starter code. Validation report starts with explicit pending evidence text that benchmark execution replaces with measured values.
- Type consistency: engine adapters share `EngineConfig`, `EngineResult`, and `benchmark_sample` boundary so later tasks reuse same names.
