from __future__ import annotations

from pathlib import Path

from tools.benchmarks.stt_engine_base import SpeechBenchmarkEngine
from tools.benchmarks.stt_eval import score_transcript


def benchmark_sample(
    engine: SpeechBenchmarkEngine,
    sample: dict[str, str],
) -> dict[str, object]:
    audio_path = Path(sample["audio_path"])
    result = engine.transcribe(audio_path, sample["mode"])
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
