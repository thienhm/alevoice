from __future__ import annotations

import json
from pathlib import Path

REQUIRED_KEYS = {"id", "audio_path", "reference", "mode", "category"}


def load_corpus(path: Path) -> list[dict[str, str]]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    for row in rows:
        missing = REQUIRED_KEYS - row.keys()
        if missing:
            raise ValueError(f"missing required keys: {sorted(missing)}")
    return rows
