from __future__ import annotations

import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

from tools.benchmarks.stt_engine_base import EngineConfig, EngineResult


@dataclass(frozen=True)
class FunASREngine:
    config: EngineConfig

    def build_command(self, audio_path: Path, mode: str) -> list[str]:
        return [
            self.config.binary,
            "-m",
            self.config.model,
            "-a",
            str(audio_path),
        ]

    @staticmethod
    def parse_transcript(stdout: str) -> str:
        return stdout.strip()

    def transcribe(self, audio_path: Path, mode: str) -> EngineResult:
        start = time.perf_counter()
        completed = subprocess.run(
            self.build_command(audio_path, mode),
            capture_output=True,
            text=True,
            check=True,
        )
        end = time.perf_counter()
        return EngineResult(
            transcript=self.parse_transcript(completed.stdout),
            latency_ms=int((end - start) * 1000),
        )
