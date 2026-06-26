from __future__ import annotations

import argparse
import json
from pathlib import Path


def summarize_rows(rows: list[dict[str, object]]) -> dict[str, dict[str, float]]:
    grouped: dict[str, list[dict[str, object]]] = {}
    for row in rows:
        grouped.setdefault(str(row["engine"]), []).append(row)

    return {
        engine: {
            "avg_latency_ms": sum(int(item["latency_ms"]) for item in items) / len(items),
            "exact_match_rate": sum(1 for item in items if item["exact_match"]) / len(items),
        }
        for engine, items in grouped.items()
    }


def load_rows(input_dir: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for path in sorted(input_dir.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(payload, list):
            rows.extend(item for item in payload if isinstance(item, dict))
            continue
        if isinstance(payload, dict):
            rows.append(payload)
    return rows


def write_report(summary: dict[str, dict[str, float]], report_path: Path) -> None:
    lines = [
        "# STT Engine Benchmark Report",
        "",
        "## Aggregate Summary",
        "",
        "| Engine | Avg latency ms | Exact match rate |",
        "| --- | ---: | ---: |",
    ]
    for engine, metrics in sorted(summary.items()):
        avg_latency = metrics["avg_latency_ms"]
        exact_match_rate = metrics["exact_match_rate"]
        lines.append(f"| {engine} | {avg_latency:.1f} | {exact_match_rate:.2f} |")

    lines.extend(
        [
            "",
            "## Recommendation",
            "",
            "Recommendation: pending measured review.",
            "",
            "No MVP engine is selected until local benchmark outputs are reviewed.",
            "",
        ]
    )
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines), encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Summarize STT benchmark rows by engine.")
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize_rows(load_rows(args.input_dir))
    if args.report:
        write_report(summary, args.report)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
