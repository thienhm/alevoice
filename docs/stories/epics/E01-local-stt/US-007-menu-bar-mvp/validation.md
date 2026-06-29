# Validation

## Proof Strategy

This story is complete only when automated tests cover the new formatting and
session-state behavior, the app behaves as a resident menu bar utility in local
platform use, the waveform menu bar icon turns red while recording, no floating
overlay appears for any session state, copyable error affordances are present,
and focused-app paste proof is recorded in updated validation notes.

## Test Plan

| Layer | Cases |
| --- | --- |
| Unit | `TranscriptFormatter` English and Vietnamese commands, normal text preservation, Auto-only recording path, session-state transitions |
| Integration | Recording transcripts are formatted before paste, sample transcription remains display-only, menu state adapters reflect view-model state, overlay rendering remains hidden |
| E2E | Not required as a separate automated layer for this local macOS MVP |
| Platform | Menu bar launch, open settings window, global shortcut recording, red menu bar waveform icon while recording, no floating overlay, TextEdit plus Notes or browser paste proof |
| Performance | Existing local latency display remains intact; no new performance target is introduced in this slice |
| Logs/Audit | Story evidence, validation note, matrix row, and trace are updated |

## Fixtures

- Existing sample audio under `data/benchmarks/samples/`
- Existing local FunASR config under `Config/`
- TextEdit and either Notes or a browser text field for focused paste proof

## Commands

Expected commands:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path
rtk ./scripts/bin/harness-cli story verify US-007
```

## Acceptance Evidence

2026-06-27 automated proof:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
  passed with 87 tests and 0 failures.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path`
  built and ad-hoc signed `.build/debug/AleVoiceApp.app`.
- Permission regression follow-up: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
  passed with 90 tests and 0 failures after adding explicit microphone request
  UI coverage and changing Input Monitoring request/re-check to report
  `unknown` when Quartz cannot confirm authorization.
- Privacy-pane follow-up: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
  passed with 93 tests and 0 failures after changing Accessibility
  request/re-check to report `unknown` unless trust is confirmed and adding
  explicit Accessibility/Input Monitoring System Settings open actions.
- Validation closeout follow-up:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
  passed with 94 tests and 0 failures after adding direct Accessibility
  request-path regression coverage, and
  `rtk ./scripts/bin/harness-cli story verify US-007` passed.
- Menu bar feedback follow-up:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
  passed with 95 tests and 0 failures after replacing floating overlay
  feedback with a red waveform icon during recording and adding copyable
  last-error affordances.
- Enable-toggle follow-up:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/rtk swift test --filter TranscriptionDebugViewModelTests`
  passed with 22 tests and 0 failures, `... swift test --filter
  GlobalHotkeyDebugViewModelTests` passed with 13 tests and 0 failures, and
  `... swift test --filter MenuBarMenuViewTests` passed with 4 tests and 0
  failures after adding a persistent dictation enable toggle, blocking disabled
  dictation starts, keeping sample transcription usable while disabled, and
  removing permission status rows from the menu bar menu.
- Enable-toggle final proof:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/rtk swift test`
  passed with 115 tests and 0 failures,
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /opt/homebrew/bin/rtk ./scripts/run-alevoice-app --print-bundle-path`
  built, ad-hoc signed, and printed `.build/debug/AleVoiceApp.app`, and
  `/opt/homebrew/bin/rtk /Users/alex/workspace/Projects/alevoice/scripts/bin/harness-cli story verify US-007`
  passed. The Codex worktree did not include `scripts/bin/harness-cli`, so the
  source checkout's prebuilt Harness binary was used against this worktree.

2026-06-27 platform proof:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app`
  launched the local app bundle.
- `pgrep -fl AleVoiceApp` showed the app process running from
  `.build/arm64-apple-macosx/debug/AleVoiceApp.app/Contents/MacOS/AleVoiceApp`.
- System Events reported the app process as `frontmost=false`,
  `background only=true`, and `visible=false`, matching resident/accessory
  utility behavior.
- System Events exposed menu bar 2 as a `waveform` status menu.
- Opening the menu exposed Idle state, Microphone/Accessibility/Input
  Monitoring rows, shortcut row, Open Settings, and Quit AleVoice.
- Clicking Open Settings opened the `AleVoice Settings` window.
- Settings content included `Dictation mode: Auto`.
- Settings content included `Microphone permission: not determined`,
  `Accessibility: not determined`, `Input Monitoring: not determined`, the
  configured shortcut row, and idle recorder state.
- Expected follow-up platform proof: hold the configured shortcut and confirm
  the waveform icon turns red while recording, release the shortcut and confirm
  the icon returns to default styling, confirm no floating overlay appears for
  recording, processing, success, or error states, and trigger an error to
  confirm it can be copied from Settings or `Copy Last Error`.
- Settings now includes an explicit `Request Microphone` action.
- Settings now includes direct `Open Settings` actions for Accessibility and
  Input Monitoring.
- Accessibility request/re-check no longer shows a hard denial when the prompt
  path does not confirm trust; the app reports `unknown` unless authorization
  is actually confirmed.
- Input Monitoring request/re-check no longer shows a hard denial when Quartz
  returns no confirmed authorization; the app reports `unknown` and preserves
  the request-attempt marker for follow-up refresh.
- Expected current menu shape follow-up: Idle/Recording state text, `Enabled`
  toggle, shortcut row, optional `Copy Last Error`, `Open Settings`, and `Quit
  AleVoice`; permission status rows should no longer appear in the menu.

Remaining platform gate:

- The rebuilt ad-hoc bundle currently reports `Microphone permission: not
  determined`, `Accessibility: not determined`, and `Input Monitoring: not
  determined` before local TCC approval.
- Final app-driven focused TextEdit plus second-field paste proof still
  requires approving at least Microphone and Accessibility for
  `dev.alevoice.AleVoiceApp`, then rerunning focused-field dictation/paste
  validation. Input Monitoring remains required for full global-hotkey
  platform proof.
