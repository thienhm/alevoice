from __future__ import annotations

import json
from pathlib import Path

REQUIRED_KEYS = {"id", "audio_path", "reference", "mode", "category"}
ALLOWED_MODES = {"auto", "en", "vi"}


def load_corpus(path: Path) -> list[dict[str, str]]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(rows, list):
        raise ValueError("corpus must be a list")

    seen_ids: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ValueError(f"corpus row {index} must be an object")

        missing = REQUIRED_KEYS - row.keys()
        if missing:
            raise ValueError(f"missing required keys: {sorted(missing)}")

        for key in REQUIRED_KEYS:
            value = row[key]
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"corpus row {index} field {key} must be a non-empty string")

        if row["mode"] not in ALLOWED_MODES:
            raise ValueError(f"corpus row {index} has invalid mode: {row['mode']}")

        if row["id"] in seen_ids:
            raise ValueError(f"corpus row {index} has duplicate id: {row['id']}")
        seen_ids.add(row["id"])

    return rows
