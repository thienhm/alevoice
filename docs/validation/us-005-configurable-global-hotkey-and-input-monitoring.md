# US-005 Validation Report

## Summary

Validation report for configurable global hotkey and Input Monitoring lifecycle.
This run proves shortcut capture/persistence, visible permission state, app
launch, unit coverage, integration coverage, and sample transcription. It does
not claim full platform global hold/release proof because this machine reports
Input Monitoring denied.

## Commands Run

| Command | Result |
| --- | --- |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test` | Passed on 2026-06-27 with 67 tests and 0 failures. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path` | Built, signed, and reported `/Users/alex/workspace/Projects/alevoice/.build/debug/AleVoiceApp.app`. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app` | Built, signed, and opened the AleVoiceApp bundle successfully. |

## Expected Results

| Check | Expected proof |
| --- | --- |
| Unit | Shortcut modeling, persistence, and state-machine tests pass. |
| Integration | Debug view model applies captured shortcut and routes release to existing transcription path. |
| E2E | Not required for this slice; no paste automation or overlay yet. |
| Platform | Configured shortcut starts and stops recording globally on target Mac after Input Monitoring approval. Current machine proof is blocked because Input Monitoring reports denied. |
| Release | Commands, observed UI proof, platform blocker, and known shortcut limitations are recorded here. |

## Platform Proof

Direct app inspection and local interaction on 2026-06-27 showed:

- `Microphone permission: not determined`.
- `Input Monitoring: not determined` initially.
- `Dictation shortcut: not set`.
- `Record shortcut` button.
- `Request / Re-check` button.
- Clicking `Record shortcut` showed `Press shortcut keys` and disabled manual controls.
- Pressing `Control+Space` while capture mode was active updated the UI to `Dictation shortcut: Control+Space`.
- Persisted shortcut data exists in app defaults after capture.
- Clicking `Transcribe en-001 sample` rendered `404 ms` and `open terminal and show get status`.
- Clicking `Request / Re-check` changed visible status to `Input Monitoring: denied` on this machine.

Because Input Monitoring is denied on this machine, this run could not
truthfully verify that holding the configured shortcut starts recording globally
or that releasing it stops and transcribes.

## Known Limits

- Paste automation is out of scope.
- Overlay UI is out of scope.
- Formatting-command normalization is out of scope.
- Conflict resolution is limited to rejecting unsupported or modifier-free
  shortcuts.
- Full platform hold/release proof requires a machine where Input Monitoring is
  approved for the signed app bundle.
