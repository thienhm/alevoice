# US-005 Validation Report

## Summary

Validation plan for configurable global hotkey and Input Monitoring lifecycle.
Proof should show that persisted shortcut capture, Input Monitoring status, and
global hold/release events drive the existing recording and transcription path.

## Commands Run

Add commands after implementation.

## Expected Results

| Check | Expected proof |
| --- | --- |
| Unit | Shortcut modeling, persistence, and state-machine tests pass. |
| Integration | Debug view model applies captured shortcut and routes release to existing transcription path. |
| E2E | Not required for this slice; no paste automation or overlay yet. |
| Platform | Configured shortcut starts and stops recording globally on target Mac after Input Monitoring approval. |
| Release | Commands, platform proof, and known shortcut limitations are recorded here. |

## Platform Proof

Add target-Mac proof after implementation, including Input Monitoring approval
state, configured shortcut, recording start on hold, and transcription on
release.

## Known Limits

- Paste automation is out of scope.
- Overlay UI is out of scope.
- Formatting-command normalization is out of scope.
- Conflict resolution is limited to rejecting unsupported or modifier-free
  shortcuts.
