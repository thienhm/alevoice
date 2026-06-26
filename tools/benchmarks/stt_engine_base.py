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
