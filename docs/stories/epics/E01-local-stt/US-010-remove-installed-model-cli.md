# US-010 Remove Installed Model CLI

## Status

implemented

## Lane

normal

## Product Contract

AleVoice can remove an installed local model through an interactive CLI command
that updates engine config and deletes the managed runtime/model payloads for
the selected engine.

## Relevant Product Docs

- `README.md`
- `docs/product/local-dictation-workflow.md`
- `docs/superpowers/specs/2026-06-30-remove-installed-model-cli-design.md`

## Acceptance Criteria

- `AleVoiceCLI remove` lists installed engines from `Config/speech-engine.json`.
- The current selected engine is visibly marked in the list.
- User selection is numeric and invalid selections fail without mutation.
- Removal requires explicit confirmation.
- Confirmed removal deletes the config entry and
  `~/Library/Application Support/AleVoice/engines/<engine-id>`.
- Removing the selected engine chooses a remaining engine and valid default
  mode.
- The last remaining installed engine cannot be removed.

## Design Notes

- Commands: `AleVoiceCLI remove`
- Domain rules: at least one installed engine must remain; fallback selection is
  deterministic by sorted engine id.
- UI surfaces: CLI only.

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-010 --unit 1 --integration 1 --e2e 0 --platform 0`.

| Layer | Expected proof |
| --- | --- |
| Unit | Remover service and CLI interaction tests cover success, cancel, invalid input, fallback, and last-engine rejection. |
| Integration | Full Swift test suite passes. |
| E2E | Not required for this slice. |
| Platform | Not required; filesystem behavior uses temp directories in tests. |
| Release | README and product contract mention the remove workflow. |

## Harness Delta

No harness change expected.

## Evidence

2026-06-30:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
  passed with 141 tests and 0 failures.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI --help`
  showed `remove` and the deletion note.
- Interactive remove behavior is covered by CLI/unit tests for confirmed
  removal, cancellation, invalid selection, selected-engine fallback, and
  last-engine rejection.
