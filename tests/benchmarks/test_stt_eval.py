from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace

import pytest

from tools.benchmarks.run_stt_benchmark import benchmark_sample
from tools.benchmarks.stt_engine_base import EngineConfig, EngineResult
from tools.benchmarks.stt_engine_funasr import FunASREngine
from tools.benchmarks.stt_engine_whispercpp import WhisperCppEngine
from tools.benchmarks.stt_eval import normalize_text, score_transcript
from tools.benchmarks.summarize_stt_benchmark import summarize_rows


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
