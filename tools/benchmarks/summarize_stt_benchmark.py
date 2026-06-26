from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.append(str(Path(__file__).resolve().parents[2]))


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


def choose_recommendation(summary: dict[str, dict[str, float]]) -> tuple[str, str]:
    whisper = summary.get("whispercpp")
    funasr = summary.get("funasr")
    if whisper is None or funasr is None:
        return ("pending", "Both whispercpp and funasr benchmark rows are required.")

    if (
        funasr["exact_match_rate"] > whisper["exact_match_rate"]
        and funasr["avg_latency_ms"] <= whisper["avg_latency_ms"]
    ):
        return (
            "funasr",
            "FunASR is faster and achieved a higher exact-match rate on this corpus.",
        )

    return (
        "whispercpp",
        "Defaulted to whispercpp because FunASR was not materially better on both quality and latency.",
    )


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


def collect_weak_cases(rows: list[dict[str, object]]) -> list[str]:
    weak_cases: list[str] = []
    for row in rows:
        if row.get("exact_match"):
            continue
        weak_cases.append(
            f"- {row['engine']} / {row['sample_id']} ({row['category']}): "
            f"reference=`{row['reference']}` transcript=`{row['transcript']}`"
        )
    return weak_cases


def write_report(
    summary: dict[str, dict[str, float]],
    report_path: Path,
    *,
    rows: list[dict[str, object]] | None = None,
) -> None:
    recommendation, reason = choose_recommendation(summary)
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
            f"Recommendation: {recommendation}.",
            "",
            reason,
            "",
        ]
    )

    weak_cases = collect_weak_cases(rows or [])
    if weak_cases:
        lines.extend(
            [
                "## Known Weak Cases",
                "",
                *weak_cases,
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
    rows = load_rows(args.input_dir)
    summary = summarize_rows(rows)
    if args.report:
        write_report(summary, args.report, rows=rows)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
