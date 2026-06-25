from tools.benchmarks.stt_eval import normalize_text, score_transcript


def test_normalize_text_collapses_spacing_and_case():
    assert normalize_text("  Xin   Chao  ") == "xin chao"


def test_score_transcript_returns_exact_match_for_identical_text():
    score = score_transcript("new line", "new line")
    assert score.exact_match is True
    assert score.reference_tokens == 2
