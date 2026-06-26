# Configurable Global Hotkey Design

## Context

`US-001` through `US-004` established local STT engine benchmarking, a
FunASR-first native transcription core, native microphone recording, and a
reliable debug app shell with microphone permission visibility.

Current app state:

- native debug app can launch and transcribe sample audio
- live microphone recording can start and stop from UI buttons
- microphone permission status is visible in UI
- no global trigger exists yet
- no Input Monitoring permission surface exists yet
- no paste automation or overlay work exists yet

Original design spec named `Right Option` as the trigger, but product direction
for next slice is broader: user must be able to choose the shortcut instead of
using a hard-coded key.

## Decision

Implement global hold-to-record with a user-recorded shortcut capture flow.

The shortcut system should support:

- at least one modifier key
- optional primary key
- modifier-only shortcuts where macOS event stream makes them reliable
- modifier-plus-key shortcuts such as `Control+Space` or `Command+Shift+D`

The shortcut system should reject bare non-modifier keys for MVP.

## Goals

- Let user record and save a dictation shortcut in app UI.
- Detect global shortcut press and release outside app focus.
- Start recording when configured shortcut becomes active.
- Stop recording and begin transcription when configured shortcut releases.
- Expose Input Monitoring permission state and re-check/request guidance in UI.
- Reuse existing recording and transcription pipeline from `US-003` and
  `US-004`.

## Non-Goals

- Paste transcript into focused app.
- Add floating overlay or menu bar polish.
- Add formatting-command normalization.
- Support arbitrary bare character keys without modifiers.
- Solve every system shortcut conflict in MVP.
- Replace existing manual debug buttons.

## Product Behavior

Expected user flow:

1. User launches app.
2. App shows microphone permission state and Input Monitoring state.
3. User clicks `Record shortcut`.
4. App enters capture mode and prompts user to press desired shortcut.
5. App validates captured chord.
6. Valid shortcut is saved and displayed in human-readable form.
7. When user holds shortcut globally, app starts microphone capture.
8. When user releases any required part of shortcut, app stops recording and
   transcribes through existing FunASR-first path.

Rules:

- App should default to `no shortcut configured` instead of hard-coding
  `Right Option`.
- Captured shortcut must include at least one modifier.
- Capture mode must suppress live dictation triggering so editing shortcut does
  not accidentally start recording.
- Recording should start once per activation, even if repeated key events
  arrive while shortcut stays held.
- Recording should stop once when shortcut is no longer fully active.
- If Input Monitoring permission is unavailable, shortcut monitoring stays
  disabled and UI explains why.
- Manual start/stop buttons remain available as debug fallback.

## Architecture

Recommended components:

### `HotkeyDefinition`

Persisted representation of chosen shortcut.

Fields:

- required modifiers
- optional primary key
- display text

Responsibilities:

- validate captured chord
- reject disallowed combinations
- provide stable display string for UI and tests

### `HotkeyCaptureController`

Short-lived controller active only during shortcut capture.

Responsibilities:

- observe next user-entered chord
- normalize event data into `HotkeyDefinition`
- reject bare keys and malformed chords
- return success or user-visible validation error

### `GlobalHotkeyMonitor`

Long-lived monitor for global key activity.

Responsibilities:

- install and own Quartz event tap
- watch `keyDown`, `keyUp`, and `flagsChanged`
- track current pressed-state model
- emit activation and release transitions for configured shortcut

This component should not know about recording, transcription, or UI strings.

### `InputMonitoringPermission`

Small permission wrapper dedicated to keyboard-listening capability.

Responsibilities:

- report current permission state
- trigger permission request/check path
- expose state in app-friendly form for UI

This should stay separate from microphone permission handling because paste
automation and other accessibility flows are future work.

### `HoldToRecordCoordinator`

Bridge from hotkey transitions into existing recorder path.

Responsibilities:

- on shortcut activation: call existing start-recording flow
- on shortcut release: call existing stop-and-transcribe flow
- prevent duplicate starts/stops from noisy event streams
- ignore triggers while capture mode is active

## Event Monitor Strategy

Use Quartz event tap as monitoring backbone for this slice.

Why:

- global shortcut detection needs key down/up and modifier-state transitions
- event tap gives lower-level keyboard visibility than current SwiftUI app layer
- Input Monitoring permission naturally belongs with this capability

Expected event handling model:

- `flagsChanged` updates modifier pressed-state
- `keyDown` and `keyUp` update optional primary-key pressed-state
- when current state satisfies configured shortcut and previous state did not,
  emit activation
- when previous state satisfied configured shortcut and current state does not,
  emit release

This approach supports both:

- modifier-only shortcuts, if event stream is reliable enough for chosen keys
- modifier-plus-key shortcuts

If some modifier-only combinations prove inconsistent in platform validation,
document exact limitation and narrow accepted set rather than silently changing
release semantics.

## UI Changes

Add to current debug shell:

- `Input Monitoring: <status>` row
- `Request / Re-check` button
- `Dictation shortcut: <current value>` row
- `Record shortcut` button
- capture-mode helper text such as `Press shortcut...`
- validation error text when user records invalid shortcut

State examples:

- `Dictation shortcut: not set`
- `Dictation shortcut: Control+Space`
- `Input Monitoring: denied`
- `Waiting for shortcut`
- `Recording in progress`
- `Transcribing recording`

Existing language-mode picker and manual microphone buttons remain unchanged.

## Persistence

Shortcut choice should be persisted locally so user does not need to re-record
it on every launch.

MVP persistence can use app-local preferences storage as long as:

- read path is centralized
- invalid stored values fail closed to `no shortcut configured`
- display text is derived from structured stored data, not stored as source of
  truth

## Error Handling

User-visible errors should cover:

- shortcut missing required modifier
- unsupported captured shortcut
- Input Monitoring permission unavailable or denied
- recording start failure after shortcut activation
- transcription failure after release

Behavioral rules:

- invalid shortcut does not replace prior valid shortcut
- permission failure does not crash app or start partial monitor state
- hotkey monitor teardown should happen cleanly when app exits or settings
  change

## Validation

### Unit

- `HotkeyDefinition` accepts supported chords and rejects bare keys
- display text is stable and human-readable
- pressed-state matching handles modifier-only and modifier-plus-key cases
- repeated key events do not retrigger active recording
- release transition fires once

### UI / View Model

- capture mode enters and exits correctly
- valid shortcut updates displayed value
- invalid shortcut surfaces clear error
- missing permission disables trigger-dependent flow and updates status text
- capture mode suppresses active global trigger handling

### Integration

- persisted shortcut reloads on app launch
- configured shortcut drives existing start/stop/transcribe flow without
  changing language-mode behavior

### Platform

- app launches
- Input Monitoring state is visible
- user records shortcut successfully
- holding shortcut starts recording
- releasing shortcut stops recording and transcribes
- manual debug controls still function

## Risks

- some shortcuts may conflict with system or app shortcuts
- modifier-only reliability may vary by key and event path
- Input Monitoring request UX can be awkward and may require user guidance to
  Settings
- capture mode can accidentally reuse stale pressed-state unless explicitly
  reset

## Story Shape

This should become `US-005 configurable global hotkey and Input Monitoring hold
lifecycle`.

Suggested acceptance criteria:

- user can record shortcut in UI and see persisted value
- invalid shortcuts are rejected with clear error
- Input Monitoring state is visible in UI
- global shortcut activation starts recording once
- shortcut release stops recording and transcribes once
- existing manual recorder controls still work
- no paste, overlay, or formatting behavior is added in this slice

## Follow-On Stories

Expected next slices after `US-005`:

- paste transcript into focused app
- overlay recording/processing indicator
- formatting-command normalization
- conflict detection or richer shortcut preferences
