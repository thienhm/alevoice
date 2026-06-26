from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from tools.benchmarks.stt_engine_base import EngineConfig, EngineResult


@dataclass(frozen=True)
class FunASREngine:
    config: EngineConfig

    def build_command(self, audio_path: Path, mode: str) -> list[str]:
        mode_args = [] if mode == "auto" else ["--language", mode]
        return [
            self.config.binary,
            "--model",
            self.config.model,
            "--audio",
            str(audio_path),
            *mode_args,
        ]

    def transcribe(self, audio_path: Path, mode: str) -> EngineResult:
        raise NotImplementedError
