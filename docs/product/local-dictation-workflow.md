# Local Dictation Workflow

## Goal

Define the current native macOS dictation workflow for the menu bar MVP.

## Source-First Setup

- Alpha users install the current pinned runtime/model with
  `swift run AleVoiceCLI setup funasr-sensevoice`.
- Setup writes repo-local config at `Config/speech-engine.json`.
- Managed runtime/model artifacts live under
  `~/Library/Application Support/AleVoice/`.
- The app bundle itself does not embed third-party runtime/model payloads in
  this source-first phase.

## Current Workflow Contract

- User launches resident menu bar app locally.
- User can inspect microphone, Accessibility, and Input Monitoring status from
  the settings/debug window.
- User can explicitly request microphone permission from the settings/debug
  window before recording.
- User can open the Accessibility and Input Monitoring privacy panes directly
  from the settings/debug window.
- MVP dictation uses Auto language mode.
- User can enable or disable dictation from the menu bar menu and the
  settings/debug window.
- Dictation stays enabled by default across relaunches.
- User can record a dictation shortcut in UI.
- App persists chosen shortcut locally.
- When dictation is disabled, the app ignores global shortcut activation and
  manual microphone capture start requests.
- Sample transcription, permission actions, settings links, and shortcut setup
  remain usable while dictation is disabled.
- Holding configured shortcut starts microphone capture.
- If Accessibility cannot be confirmed after a prompt or re-check, the app
  reports the state as unknown rather than a definitive denial.
- If Input Monitoring cannot be confirmed by Quartz after a request/re-check,
  the app reports the state as unknown rather than a definitive denial.
- App indicates active recording by turning the menu bar waveform icon red while
  the configured shortcut is held.
- The menu bar menu shows current state, the enabled toggle, the shortcut row,
  settings access, and quit; permission status rows live only in the
  settings/debug window.
- App does not show floating overlay feedback for recording, processing,
  success, or error states.
- Error text remains copyable from the settings/debug window and from the menu
  bar error action.
- Releasing configured shortcut stops capture and transcribes through the
  current FunASR-first path.
- Successful recording transcription is normalized through the small
  formatting-command formatter.
- Successful recording transcription is pasted into the currently focused app
  through clipboard-backed paste automation.
- User can open settings/debug UI from the menu bar.

## Out Of Scope

- Forced English or Vietnamese recognition mode in the MVP workflow.
- Caret-relative overlay placement.
- Distribution packaging and notarization.
- Conflict resolution beyond rejecting unsupported or modifier-free shortcuts
