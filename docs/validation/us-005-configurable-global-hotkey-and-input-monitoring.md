# US-005 Validation Report

## Summary

Validation report for configurable global hotkey and Input Monitoring lifecycle.
This run proves shortcut capture/persistence, visible permission state, app
launch, unit coverage, integration coverage, and full platform global
hold/release proof for the signed AleVoiceApp bundle on this Mac.

## Commands Run

| Command | Result |
| --- | --- |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter QuartzInputMonitoringPermissionTests` | Failed before implementation because the adapter had no injectable Quartz seam, then passed after adding the stale-request regression. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test` | Passed on 2026-06-27 with 68 tests and 0 failures. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path` | Built, signed, and reported `/Users/alex/workspace/Projects/alevoice/.build/debug/AleVoiceApp.app`. |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app` | Built, signed, and opened the AleVoiceApp bundle successfully. |
| `rtk run 'codesign -dv --verbose=4 .build/debug/AleVoiceApp.app 2>&1'` | Confirmed bundle identifier `dev.alevoice.AleVoiceApp` and ad-hoc signature for the launched app bundle. |
| `rtk run 'tccutil reset ListenEvent dev.alevoice.AleVoiceApp'` | Reset stale Input Monitoring approval state for the bundle id so the current signed app could be re-evaluated by TCC. |

## Expected Results

| Check | Expected proof |
| --- | --- |
| Unit | Shortcut modeling, persistence, state-machine, and Input Monitoring status adapter tests pass. |
| Integration | Debug view model applies captured shortcut and routes release to existing transcription path. |
| E2E | Not required for this slice; no paste automation or overlay yet. |
| Platform | Configured shortcut starts and stops recording globally on target Mac after Input Monitoring approval. |
| Release | Commands, observed UI proof, and known shortcut limitations are recorded here. |

## Status Truthfulness

The app now treats a passive Input Monitoring status refresh as authorized only
when live Quartz preflight succeeds. If Quartz preflight is false and the only
denial evidence is the persisted local request-attempt flag, the adapter reports
`unknown` instead of `denied`; an explicit `Request / Re-check` can still return
`denied` from the immediate request result. This avoids overstating OS-side
denial after `tccutil reset ListenEvent dev.alevoice.AleVoiceApp` or stale
ad-hoc bundle TCC rows.

## Platform Proof

Direct app inspection and local interaction on 2026-06-27 showed:

- `Microphone permission: not determined` initially.
- `Input Monitoring: not determined` initially.
- `Dictation shortcut: Control+Space` persisted on launch.
- `Request / Re-check` initially drove the UI to `Input Monitoring: denied`.
- macOS System Settings opened to `Privacy & Security > Input Monitoring` and listed `AleVoiceApp`.
- `tccd` logs showed `Failed to match existing code requirement` for `dev.alevoice.AleVoiceApp` on `kTCCServiceListenEvent`, which explained the stale denied state despite a visible Settings row.
- After `tccutil reset ListenEvent dev.alevoice.AleVoiceApp` and relaunching the existing `.build/debug/AleVoiceApp.app` bundle, the app showed `Input Monitoring: authorized`.
- Manual platform validation then completed on the same signed bundle: microphone access was approved, holding global `Control+Space` started recording once, and releasing `Control+Space` stopped recording and transcribed once through the existing local STT path.
- No paste, overlay, or formatting behavior was added during this validation.

## Known Limits

- Paste automation is out of scope.
- Overlay UI is out of scope.
- Formatting-command normalization is out of scope.
- Conflict resolution is limited to rejecting unsupported or modifier-free
  shortcuts.
- This machine has no valid local code-signing identities, so the launcher uses
  ad-hoc signing. TCC permission rows can become stale across rebuilt app
  bundles and may require a `ListenEvent` reset and relaunch to re-establish a
  matching code requirement for platform validation.
