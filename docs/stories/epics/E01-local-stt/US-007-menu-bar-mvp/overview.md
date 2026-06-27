# Overview

## Current Behavior

AleVoice currently works as a foreground SwiftUI debug app with a local
dictation core:

- Microphone recording can be started from UI buttons or a configurable global
  shortcut.
- Successful recording transcription can be pasted into the focused app through
  clipboard-backed paste automation.
- The app exposes Microphone, Accessibility, and Input Monitoring status in the
  debug window.
- Sample transcription remains a display-only debug path.

The current product shape is still incomplete for MVP:

- the app launches as a regular app window instead of a resident menu bar app
- there is no overlay feedback while dictating
- forced language modes remain exposed even though the current FunASR runtime
  does not support explicit `en` or `vi`
- formatting commands are not normalized before paste
- root `README.md` still describes the generic Harness repository instead of
  AleVoice
- focused-app paste proof for the current paste slice still needs to be closed

## Target Behavior

AleVoice should ship as a local menu bar MVP:

- resident macOS menu bar app
- settings/debug window opened from the menu bar
- Auto-only dictation path for MVP
- tiny overlay for recording, processing, success, and error states
- deterministic formatting normalization before paste
- completed manual paste proof in focused text fields
- README aligned with actual AleVoice product and development workflow

## Affected Users

- Primary local user dictating prompts or text into macOS apps.
- Developer validating local STT, permissions, and platform behavior.

## Affected Product Docs

- `docs/product/local-dictation-workflow.md`
- `docs/superpowers/specs/2026-06-27-menu-bar-mvp-design.md`
- `docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md`

## Non-Goals

- Caret-relative overlay placement.
- Forced English or Vietnamese recognition mode in the MVP path.
- Complex grammar correction or large-scale transcript rewriting.
- Notarization, installer packaging, or release distribution work.
