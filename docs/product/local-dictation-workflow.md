# Local Dictation Workflow

## Goal

Define current native macOS dictation workflow after benchmark phase.

## Current Workflow Contract

- User launches native debug app locally.
- User can inspect microphone and Input Monitoring status in app UI.
- User can choose language mode for transcription.
- User can record a dictation shortcut in UI.
- App persists chosen shortcut locally.
- Holding configured shortcut starts microphone capture.
- Releasing configured shortcut stops capture and transcribes through current
  FunASR-first path.

## Out Of Scope

- Paste transcript into focused app
- Overlay UI
- Formatting-command normalization
- Conflict resolution beyond rejecting unsupported or modifier-free shortcuts
