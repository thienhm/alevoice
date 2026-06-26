from __future__ import annotations

import json
from pathlib import Path
from types import SimpleNamespace

import pytest

from tools.benchmarks.run_stt_benchmark import (
    benchmark_sample,
    load_engine_config,
    run_benchmark,
)
from tools.benchmarks.stt_engine_base import EngineConfig, EngineResult
from tools.benchmarks.stt_engine_funasr import FunASREngine
from tools.benchmarks.stt_engine_whispercpp import WhisperCppEngine
from tools.benchmarks.stt_eval import normalize_text, score_transcript
from tools.benchmarks.summarize_stt_benchmark import summarize_rows, write_report


class FakeEngine:
    def __init__(self) -> None:
        self.config = EngineConfig(name="fake", binary="fake", model="fake")

    def transcribe(self, audio_path: Path, mode: str) -> EngineResult:
        return EngineResult(transcript="hello", latency_ms=123)


def test_normalize_text_collapses_spacing_and_case():
    assert normalize_text("  Xin   Chao  ") == "xin chao"


def test_score_transcript_returns_exact_match_for_identical_text():
    score = score_transcript("new line", "new line")
    assert score.exact_match is True
    assert score.reference_tokens == 2


def test_summarize_rows_reports_average_latency_per_engine():
    rows = [
        {"engine": "whispercpp", "latency_ms": 1000, "exact_match": True, "category": "english"},
        {"engine": "whispercpp", "latency_ms": 1200, "exact_match": False, "category": "english"},
    ]
    summary = summarize_rows(rows)
    assert summary["whispercpp"]["avg_latency_ms"] == 1100


def test_benchmark_sample_records_engine_name_and_exact_match(tmp_path: Path):
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


def test_benchmark_sample_returns_expected_row_fields(tmp_path: Path):
    sample = {
        "id": "vi-001",
        "audio_path": str(tmp_path / "sample.wav"),
        "reference": "xin chao",
        "mode": "vi",
        "category": "vietnamese",
    }

    row = benchmark_sample(FakeEngine(), sample)

    assert row == {
        "sample_id": "vi-001",
        "engine": "fake",
        "category": "vietnamese",
        "mode": "vi",
        "reference": "xin chao",
        "transcript": "hello",
        "latency_ms": 123,
        "exact_match": False,
    }


def test_load_engine_config_reads_engine_from_json(tmp_path: Path):
    config_path = tmp_path / "stt_models.json"
    config_path.write_text(
        json.dumps(
            {
                "whispercpp": {
                    "binary": "/opt/bin/whisper-cli",
                    "model": "/opt/models/ggml-base.bin",
                },
                "funasr": {
                    "binary": "/opt/bin/funasr-cli",
                    "model": "/opt/models/funasr-small",
                },
            }
        ),
        encoding="utf-8",
    )

    assert load_engine_config(config_path, "whispercpp") == EngineConfig(
        name="whispercpp",
        binary="/opt/bin/whisper-cli",
        model="/opt/models/ggml-base.bin",
    )


def test_run_benchmark_writes_engine_rows_to_json(tmp_path: Path):
    class RecordingFakeEngine(FakeEngine):
        def transcribe(self, audio_path: Path, mode: str) -> EngineResult:
            return EngineResult(transcript=f"{audio_path.stem}-{mode}", latency_ms=321)

    rows = [
        {
            "id": "en-001",
            "audio_path": str(tmp_path / "sample-en.wav"),
            "reference": "sample-en-auto",
            "mode": "auto",
            "category": "english",
        },
        {
            "id": "vi-001",
            "audio_path": str(tmp_path / "sample-vi.wav"),
            "reference": "wrong-reference",
            "mode": "vi",
            "category": "vietnamese",
        },
    ]

    output_path = run_benchmark(RecordingFakeEngine(), rows, tmp_path / "out")

    assert output_path == tmp_path / "out" / "fake.json"
    assert json.loads(output_path.read_text(encoding="utf-8")) == [
        {
            "sample_id": "en-001",
            "engine": "fake",
            "category": "english",
            "mode": "auto",
            "reference": "sample-en-auto",
            "transcript": "sample-en-auto",
            "latency_ms": 321,
            "exact_match": True,
        },
        {
            "sample_id": "vi-001",
            "engine": "fake",
            "category": "vietnamese",
            "mode": "vi",
            "reference": "wrong-reference",
            "transcript": "sample-vi-vi",
            "latency_ms": 321,
            "exact_match": False,
        },
    ]


def test_write_report_writes_summary_and_pending_recommendation(tmp_path: Path):
    report_path = tmp_path / "benchmark-report.md"
    summary = {
        "whispercpp": {"avg_latency_ms": 1100.0, "exact_match_rate": 0.75},
        "funasr": {"avg_latency_ms": 900.0, "exact_match_rate": 0.5},
    }

    write_report(summary, report_path)

    content = report_path.read_text(encoding="utf-8")
    assert "## Aggregate Summary" in content
    assert "| whispercpp | 1100.0 | 0.75 |" in content
    assert "| funasr | 900.0 | 0.50 |" in content
    assert "Recommendation: pending measured review." in content


@pytest.mark.parametrize(
    ("engine_cls", "binary_arg"),
    [
        (WhisperCppEngine, "--file"),
        (FunASREngine, "--audio"),
    ],
)
def test_engine_parse_transcript_and_transcribe(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    engine_cls: type[WhisperCppEngine] | type[FunASREngine],
    binary_arg: str,
):
    calls: list[tuple[tuple[object, ...], dict[str, object]]] = []

    def fake_run(*args, **kwargs):
        calls.append((args, kwargs))
        return SimpleNamespace(stdout="  hello from engine  \n")

    perf_values = iter([10.0, 10.25])

    monkeypatch.setattr(f"{engine_cls.__module__}.subprocess.run", fake_run)
    monkeypatch.setattr(
        f"{engine_cls.__module__}.time.perf_counter",
        lambda: next(perf_values),
    )

    engine = engine_cls(EngineConfig(name="fake", binary="fake-bin", model="fake-model"))
    result = engine.transcribe(tmp_path / "sample.wav", "auto")

    assert engine.parse_transcript("  hello from engine  \n") == "hello from engine"
    assert result == EngineResult(transcript="hello from engine", latency_ms=250)
    assert calls == [
        (
            (
                [
                    "fake-bin",
                    "--model",
                    "fake-model",
                    binary_arg,
                    str(tmp_path / "sample.wav"),
                ],
            ),
            {
                "capture_output": True,
                "text": True,
                "check": True,
            },
        )
    ]
