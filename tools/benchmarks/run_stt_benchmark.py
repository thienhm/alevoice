from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.append(str(Path(__file__).resolve().parents[2]))

from tools.benchmarks.stt_corpus import load_corpus
from tools.benchmarks.stt_engine_base import EngineConfig, SpeechBenchmarkEngine
from tools.benchmarks.stt_engine_funasr import FunASREngine
from tools.benchmarks.stt_engine_whispercpp import WhisperCppEngine
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


def load_engine_config(config_path: Path, engine_name: str) -> EngineConfig:
    payload = json.loads(config_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("engine config must be an object")

    engine_payload = payload.get(engine_name)
    if not isinstance(engine_payload, dict):
        raise ValueError(f"missing config for engine: {engine_name}")

    binary = engine_payload.get("binary")
    model = engine_payload.get("model")
    if not isinstance(binary, str) or not binary.strip():
        raise ValueError(f"engine {engine_name} binary must be a non-empty string")
    if not isinstance(model, str) or not model.strip():
        raise ValueError(f"engine {engine_name} model must be a non-empty string")

    return EngineConfig(name=engine_name, binary=binary, model=model)


def build_engine(engine_name: str, config: EngineConfig) -> SpeechBenchmarkEngine:
    engine_map = {
        "whispercpp": WhisperCppEngine,
        "funasr": FunASREngine,
    }
    try:
        engine_cls = engine_map[engine_name]
    except KeyError as exc:
        raise ValueError(f"unsupported engine: {engine_name}") from exc
    return engine_cls(config)


def run_benchmark(
    engine: SpeechBenchmarkEngine,
    corpus_rows: list[dict[str, str]],
    output_dir: Path,
) -> Path:
    rows = [benchmark_sample(engine, sample) for sample in corpus_rows]
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{engine.config.name}.json"
    output_path.write_text(json.dumps(rows, indent=2), encoding="utf-8")
    return output_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run STT benchmark for one engine.")
    parser.add_argument("--engine", choices=("whispercpp", "funasr"), required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    config = load_engine_config(args.config, args.engine)
    engine = build_engine(args.engine, config)
    corpus_rows = load_corpus(args.corpus)
    output_path = run_benchmark(engine, corpus_rows, args.output_dir)
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
