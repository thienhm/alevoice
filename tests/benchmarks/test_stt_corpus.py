from tools.benchmarks.stt_corpus import load_corpus


def test_load_corpus_rejects_missing_category(tmp_path):
    corpus_path = tmp_path / "bad.json"
    corpus_path.write_text(
        """
        [
          {
            "id": "en-001",
            "audio_path": "samples/en-001.wav",
            "reference": "hello world",
            "mode": "auto"
          }
        ]
        """.strip(),
        encoding="utf-8",
    )

    try:
        load_corpus(corpus_path)
    except ValueError as exc:
        assert "category" in str(exc)
    else:
        raise AssertionError("expected ValueError")
