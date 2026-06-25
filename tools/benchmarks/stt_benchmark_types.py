from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class TranscriptScore:
    exact_match: bool
    reference_tokens: int
    hypothesis_tokens: int
