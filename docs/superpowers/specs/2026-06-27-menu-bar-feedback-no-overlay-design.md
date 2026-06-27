# Menu Bar Feedback Without Overlay Design

Date: 2026-06-27
Project: `/Users/alex/workspace/Projects/alevoice`
Status: Approved for implementation

## Context

AleVoice currently uses `DictationSessionState` to drive both the menu bar
title and a floating overlay panel. The overlay was added for MVP feedback, but
the desired product behavior has changed: recording feedback should stay in the
menu bar and the floating overlay should not appear for any state.

The user also needs failures to remain copyable. macOS menu item text is not a
reliable selectable text surface, so copyability should be provided by the
settings window and an explicit menu action.

## Decision

Remove visible overlay feedback from the MVP workflow.

Use the menu bar item as the only transient feedback surface:

- idle: normal `waveform` menu bar item
- recording: `waveform` menu bar item tinted red
- processing: normal `waveform` menu bar item
- success: normal `waveform` menu bar item
- error: normal `waveform` menu bar item, with error available in menu/settings

The red menu bar icon is only the hold-to-record indicator. It should not stay
red during processing, success, or error.

## Product Behavior

### Menu Bar

When the configured global shortcut is held and microphone capture is active,
the menu bar icon becomes red. When recording ends, the icon returns to its
default appearance.

The menu continues to show session state text. If the session state is error,
the menu shows an error state and exposes `Copy Last Error`.

`Copy Last Error` writes the exact current error message to the general
pasteboard. It is present only when an error exists.

### Settings Window

The settings/debug window continues to show the last transcript, latency, and
error. Error text in the settings window must be selectable so the user can copy
it manually.

### Overlay

No overlay panel should be shown for recording, processing, success, or error.
The overlay implementation may be removed or left inert, but it must not render
visible UI during normal app flow.

## Architecture

### `MenuBarShellModel`

Extend the shell model beyond the title so the SwiftUI `MenuBarExtra` can render
state-specific icon styling. The model should expose enough state for the app
entrypoint to choose the normal icon or recording indicator.

### `MenuBarController`

Keep `MenuBarController` responsible for translating `DictationSessionState`
into menu bar presentation state. It should not own recording, transcription,
or paste behavior.

The controller should set the red recording indicator only for
`DictationSessionState.recording`.

### `MenuBarMenuView`

Add a copy action for the current error. The view can derive the error from
`viewModel.sessionState` and write it to `NSPasteboard.general`.

### `OverlayWindowController`

Stop calling overlay rendering from session-state changes, or change the
controller so every state hides the panel. Prefer removing the call from
`AleVoiceApp` so the session-state flow has one feedback surface.

## Error Handling

- If there is no current error, `Copy Last Error` is hidden.
- Copying an error should replace the general pasteboard string.
- Copying an error should not mutate dictation session state.
- Menu bar tint changes must not interfere with transcription, paste delivery,
  or permission state.

## Validation

### Unit / Integration

- Menu bar rendering maps `recording` to the red recording indicator.
- Menu bar rendering maps idle, processing, success, and error to the default
  icon appearance.
- Session-state changes no longer ask the overlay controller to show visible UI.
- `Copy Last Error` is available when the session state is error.
- Error text remains selectable in the settings window.

### Platform

- Launch the app and confirm the overlay does not appear during recording,
  processing, success, or error.
- Hold the configured shortcut and confirm the menu bar icon turns red while
  recording.
- Release the shortcut and confirm the icon returns to normal.
- Trigger an error and confirm the error can be copied from the settings window
  or with the menu action.

## Non-Goals

- Adding caret-relative UI.
- Adding notifications.
- Changing transcription, formatting, or paste behavior.
- Changing permission semantics or TCC validation requirements.
