# Design

## Domain Model

Add a small `DictationSessionState` model for shared app UI state:

- `idle`
- `recording`
- `processing`
- `success(String?)`
- `error(String)`

Add a pure `TranscriptFormatter` component in `AleVoiceCore` that:

- preserves ordinary transcript text
- recognizes a small English and Vietnamese formatting-command vocabulary
- normalizes commands into punctuation or line breaks
- trims surrounding whitespace without becoming a grammar engine

## Application Flow

`TranscriptionDebugViewModel` remains the current application coordinator.

Recording flow:

1. Global shortcut activation or manual start begins recording.
2. View model enters `recording` state.
3. Global shortcut release or manual stop begins processing.
4. View model enters `processing` state.
5. Recording transcription runs through current core pipeline in Auto mode.
6. Formatter normalizes successful recording transcript.
7. Paste delivery receives the normalized transcript.
8. View model enters `success` or `error`.

Sample flow remains display-only:

- sample transcription does not format for output delivery
- sample transcription does not paste

## Interface Contract

No network API is involved.

Desktop/UI contracts change:

- menu bar item shows current app state
- menu bar waveform icon turns red only while recording
- menu menu shows permissions, shortcut, open settings, and quit actions
- menu exposes a copy action for the last error when an error exists
- settings/debug window remains available as a secondary surface
- settings/debug window keeps error text selectable

## Data Model

No new database tables are required.

Existing app-local shortcut persistence remains unchanged.

Story and validation evidence should be updated in the Harness durable layer.

## UI / Platform Impact

- `AleVoiceApp` should behave as a resident menu bar utility instead of a
  regular foreground-only app.
- A settings/debug window remains available on demand.
- Floating overlay feedback is disabled for recording, processing, success, and
  error states; the menu bar icon is the recording feedback surface.
- Forced language picker should be removed or collapsed away from the MVP flow
  so the primary user path is Auto-only.

## Observability

- Continue to surface transcript, latency, and latest error in the settings
  window for local debugging, with error text selectable for copying.
- Record story evidence and validation notes for the new menu bar MVP slice.

## Alternatives Considered

1. Keep the app as a foreground debug window and only add formatting and paste
   proof. Rejected because it leaves the MVP feeling like tooling, not a
   resident dictation utility.
2. Implement caret-relative overlay placement now. Rejected because it raises
   platform complexity without improving the core MVP loop enough.
