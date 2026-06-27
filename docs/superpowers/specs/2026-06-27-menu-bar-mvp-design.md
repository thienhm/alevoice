# Menu Bar MVP Design

Date: 2026-06-27
Project: `/Users/alex/workspace/Projects/alevoice`
Status: Approved for implementation

## Context

AleVoice already has the hard local dictation path in place:

- FunASR-first local transcription through a pluggable speech engine boundary.
- Native microphone recording.
- Permission status for Microphone, Input Monitoring, and Accessibility.
- Configurable global hold-to-record shortcut.
- Clipboard-backed paste into the focused app after successful recording
  transcription.

The remaining MVP gap is product shape. The app still behaves like a foreground
debug window, the original root `README.md` still describes the generic Harness
repository, forced language modes are exposed even though the current FunASR
runtime does not support them, overlay feedback is missing, formatting commands
are not normalized, and the focused-app paste slice still needs platform proof.

## Decision

Ship a menu bar MVP.

AleVoice should become a resident macOS utility whose primary workflow is:

1. User launches AleVoice.
2. App runs from the menu bar.
3. User configures permissions and a dictation shortcut from the settings/debug
   window when needed.
4. User holds the configured shortcut in any app.
5. AleVoice records while the shortcut is held and shows a tiny overlay.
6. On release, AleVoice transcribes locally in `Auto` language mode.
7. AleVoice applies small deterministic formatting-command normalization.
8. AleVoice pastes the normalized transcript into the focused app.
9. The overlay briefly shows success or error state.

`Auto` is the only MVP language mode. Forced English and Vietnamese can return
later when the runtime supports them reliably.

## Product Behavior

### Menu Bar

The menu bar item is the main app surface.

It should expose:

- Current session state: idle, recording, processing, success, or error.
- Current Microphone, Accessibility, and Input Monitoring status.
- Current shortcut display text.
- Command to open the settings/debug window.
- Command to quit AleVoice.

The app should use accessory-style behavior where possible so launching it does
not force a normal foreground document app feel.

### Settings / Debug Window

The existing SwiftUI window remains as the local settings/debug surface.

It should:

- Show permission states and request/re-check actions.
- Show current shortcut and allow re-recording it.
- Keep the manual sample and recording controls useful for local diagnostics.
- Make the MVP dictation path Auto-only. Forced language controls should not
  remain in the primary workflow while FunASR rejects explicit modes.

### Overlay

The overlay is a small, reliable feedback surface.

States:

- `idle`: hidden
- `recording`: visible while microphone capture is active
- `processing`: visible while transcription and paste delivery run
- `success`: briefly visible after paste succeeds
- `error`: visible long enough for the user to notice a failure

Placement should favor reliability over cleverness. The MVP overlay can appear
near the top center of the active screen instead of trying to follow the text
caret.

### Formatting Normalization

Formatting normalization should be deterministic and intentionally small.

Initial English commands:

- `new line` and `newline` become a line break
- `comma` becomes `,`
- `period` becomes `.`
- `question mark` becomes `?`
- `colon` becomes `:`

Initial Vietnamese commands:

- `xuong dong` and `xuống dòng` become a line break
- `dấu phẩy` becomes `,`
- `dấu chấm` becomes `.`
- `dấu hỏi` becomes `?`
- `dấu hai chấm` becomes `:`

The formatter should trim surrounding whitespace, avoid adding complex grammar,
and avoid broad rewrites that might damage bilingual prompt text.

## Architecture

### `DictationSessionState`

Small value model shared by app UI surfaces.

Responsibilities:

- Represent `idle`, `recording`, `processing`, `success`, and `error`.
- Provide display text and menu/overlay-friendly state.

### `TranscriptFormatter`

Pure `AleVoiceCore` component.

Responsibilities:

- Normalize small English and Vietnamese formatting commands.
- Preserve normal transcript text.
- Stay deterministic and easy to test.

### `TranscriptionDebugViewModel`

The current view model can remain the central application coordinator for this
MVP, but it should expose session state clearly enough for the menu bar and
overlay surfaces.

Responsibilities:

- Drive `DictationSessionState` transitions during recording, processing,
  success, and error paths.
- Use Auto mode for MVP recording and global shortcut release flows.
- Format successful recording transcripts before paste delivery.
- Keep sample transcription display-only.

### `MenuBarController`

AppKit controller owned by the `AleVoiceApp` executable.

Responsibilities:

- Own the `NSStatusItem`.
- Render menu items from current view-model state.
- Open the settings/debug window.
- Quit the app.

It should not own recording, transcription, or paste behavior.

### `OverlayWindowController`

AppKit controller owned by the `AleVoiceApp` executable.

Responsibilities:

- Own a small non-activating floating window or panel.
- Render current session state.
- Hide when idle.
- Avoid stealing focus from the target app.

It should not own recording, transcription, or paste behavior.

## Error Handling

- Permission failures should appear in the settings/debug window and overlay.
- Empty recordings should not paste.
- Formatting should be best-effort and should not throw.
- Paste failures should leave the transcript visible and show an error.
- Menu bar and overlay updates must not crash if the settings/debug window is
  closed.

## Validation

### Unit

- `TranscriptFormatter` handles English newline and punctuation commands.
- `TranscriptFormatter` handles Vietnamese newline and punctuation commands.
- `TranscriptFormatter` preserves normal bilingual text.
- `TranscriptionDebugViewModel` uses Auto mode for MVP recording flow.
- `TranscriptionDebugViewModel` formats successful recording transcripts before
  delivery.
- `TranscriptionDebugViewModel` updates session state for recording,
  processing, success, and error.

### Integration

- Sample transcription remains display-only and does not paste.
- Failed recording, empty transcript, failed transcription, and paste failure
  do not paste.
- Menu bar controller can render idle, recording, processing, success, and
  error state without owning business logic.
- Overlay controller can show and hide based on session state without stealing
  focus.

### Platform

- App launches as a resident menu bar utility.
- Settings/debug window opens from the menu.
- Global shortcut still starts and stops recording.
- Overlay appears during recording and processing.
- Successful dictation paste is manually verified into TextEdit plus one of
  Notes or a browser text field.

## Non-Goals

- Caret-relative overlay placement.
- Forced English or Vietnamese transcription mode in the MVP workflow.
- Complex text rewriting, autocapitalization, or grammar correction.
- Distribution packaging, notarization, or installer polish.
- Replacing the current FunASR backend.
