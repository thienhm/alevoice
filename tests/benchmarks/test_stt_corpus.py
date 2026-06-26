from pathlib import Path

import pytest

from tools.benchmarks.stt_engine_base import EngineConfig
from tools.benchmarks.stt_engine_funasr import FunASREngine
from tools.benchmarks.stt_engine_whispercpp import WhisperCppEngine
from tools.benchmarks.stt_corpus import load_corpus


def test_engine_config_requires_binary_and_model_paths():
    config = EngineConfig(name="whispercpp", binary="/tmp/whisper", model="/tmp/model.bin")

    assert config.name == "whispercpp"
    assert config.binary.endswith("whisper")


def test_whispercpp_build_command_includes_language_mode():
    engine = WhisperCppEngine(
        EngineConfig(name="whispercpp", binary="/tmp/whisper", model="/tmp/model.bin")
    )

    command = engine.build_command(Path("sample.wav"), "vi")

    assert command == [
        "/tmp/whisper",
        "--model",
        "/tmp/model.bin",
        "--file",
        "sample.wav",
        "--language",
        "vi",
    ]


def test_whispercpp_build_command_omits_language_for_auto_mode():
    engine = WhisperCppEngine(
        EngineConfig(name="whispercpp", binary="/tmp/whisper", model="/tmp/model.bin")
    )

    command = engine.build_command(Path("sample.wav"), "auto")

    assert command == [
        "/tmp/whisper",
        "--model",
        "/tmp/model.bin",
        "--file",
        "sample.wav",
    ]


def test_funasr_build_command_includes_language_mode():
    engine = FunASREngine(
        EngineConfig(name="funasr", binary="/tmp/funasr", model="/tmp/funasr-model")
    )

    command = engine.build_command(Path("sample.wav"), "en")

    assert command == [
        "/tmp/funasr",
        "-m",
        "/tmp/funasr-model",
        "-a",
        "sample.wav",
    ]


def test_funasr_build_command_omits_language_for_auto_mode():
    engine = FunASREngine(
        EngineConfig(name="funasr", binary="/tmp/funasr", model="/tmp/funasr-model")
    )

    command = engine.build_command(Path("sample.wav"), "auto")

    assert command == [
        "/tmp/funasr",
        "-m",
        "/tmp/funasr-model",
        "-a",
        "sample.wav",
    ]


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


def test_load_corpus_rejects_invalid_mode(tmp_path):
    corpus_path = tmp_path / "bad.json"
    corpus_path.write_text(
        """
        [
          {
            "id": "en-001",
            "audio_path": "samples/en-001.wav",
            "reference": "hello world",
            "mode": "de",
            "category": "english"
          }
        ]
        """.strip(),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="mode"):
        load_corpus(corpus_path)


def test_load_corpus_rejects_wrong_top_level_shape(tmp_path):
    corpus_path = tmp_path / "bad.json"
    corpus_path.write_text(
        """
        {
          "id": "en-001",
          "audio_path": "samples/en-001.wav",
          "reference": "hello world",
          "mode": "auto",
          "category": "english"
        }
        """.strip(),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="list"):
        load_corpus(corpus_path)


def test_load_corpus_rejects_non_string_required_field(tmp_path):
    corpus_path = tmp_path / "bad.json"
    corpus_path.write_text(
        """
        [
          {
            "id": 12,
            "audio_path": "samples/en-001.wav",
            "reference": "hello world",
            "mode": "auto",
            "category": "english"
          }
        ]
        """.strip(),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="id"):
        load_corpus(corpus_path)


def test_load_corpus_rejects_empty_required_field(tmp_path):
    corpus_path = tmp_path / "bad.json"
    corpus_path.write_text(
        """
        [
          {
            "id": "en-001",
            "audio_path": "samples/en-001.wav",
            "reference": "",
            "mode": "auto",
            "category": "english"
          }
        ]
        """.strip(),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="reference"):
        load_corpus(corpus_path)


def test_load_corpus_rejects_duplicate_ids(tmp_path):
    corpus_path = tmp_path / "bad.json"
    corpus_path.write_text(
        """
        [
          {
            "id": "dup-001",
            "audio_path": "samples/en-001.wav",
            "reference": "hello world",
            "mode": "auto",
            "category": "english"
          },
          {
            "id": "dup-001",
            "audio_path": "samples/en-002.wav",
            "reference": "xin chao",
            "mode": "vi",
            "category": "vietnamese"
          }
        ]
        """.strip(),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="duplicate|id"):
        load_corpus(corpus_path)


def test_load_corpus_rejects_missing_audio_when_required(tmp_path):
    corpus_path = tmp_path / "bad.json"
    corpus_path.write_text(
        """
        [
          {
            "id": "missing-001",
            "audio_path": "samples/missing.wav",
            "reference": "hello world",
            "mode": "auto",
            "category": "english"
          }
        ]
        """.strip(),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="audio_path|missing"):
        load_corpus(corpus_path, require_audio_exists=True)


def test_load_corpus_loads_checked_in_corpus():
    corpus_path = Path("data/benchmarks/stt_corpus.json")

    rows = load_corpus(corpus_path, require_audio_exists=True)
    ids = [row["id"] for row in rows]
    modes = {row["mode"] for row in rows}
    categories = {row["category"] for row in rows}

    assert len(ids) == len(set(ids))
    assert modes <= {"auto", "en", "vi"}
    assert {"english", "vietnamese", "mixed_vi_en", "formatting_command"} <= categories
