from __future__ import annotations

from tools.benchmarks.stt_benchmark_types import TranscriptScore


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
