# AleVoice

AleVoice is a local macOS dictation utility for speaking text into other apps.
It records while a configured global shortcut is held, transcribes locally
through the current FunASR-first speech engine path, applies small formatting
commands, and pastes the result into the focused text field.

The current MVP is a resident menu bar app with a settings/debug window for
permissions, shortcut setup, sample transcription, and local diagnostics.

## Current MVP Contract

- Runs locally on macOS 14 or newer.
- Lives in the menu bar as a resident utility.
- Uses Auto language mode for MVP dictation.
- Records while the configured shortcut is held.
- Transcribes after release through the configured local FunASR runtime.
- Normalizes a small English/Vietnamese formatting command set.
- Pastes successful recording transcripts with clipboard-backed `Cmd+V`.
- Shows small overlay feedback for recording, processing, success, and error.
- Keeps sample-audio transcription display-only.

Forced English/Vietnamese recognition, caret-relative overlay placement,
notarized packaging, and installer polish are intentionally out of scope for the
current MVP.

## Repository Shape

```text
Sources/
  AleVoiceCore/      speech engine, recorder, shortcut, formatter, core models
  AleVoiceAppUI/     SwiftUI settings/debug view and view model
  AleVoiceApp/       macOS app shell, menu bar, overlay, permissions, paste
  AleVoiceCLI/       local transcription CLI smoke path

tests/
  AleVoiceCoreTests/
  AleVoiceAppUITests/
  AleVoiceAppTests/
  benchmarks/

docs/
  product/           living product contract
  stories/           story packets and validation evidence
  validation/        proof reports
  superpowers/       design specs and implementation plans
```

The repo also carries Harness docs and the Rust Harness CLI. For agent work,
start with `AGENTS.md` and the Harness-required docs listed there.

## Local Prerequisites

- macOS 14+
- Xcode command line tools available at
  `/Applications/Xcode.app/Contents/Developer`
- Local speech engine config at `Config/speech-engine.json`
- Local FunASR runtime/model paths referenced by that config
- Microphone, Input Monitoring, and Accessibility permission for the signed app
  bundle when validating the full dictation/paste path

`Config/speech-engine.example.json` shows the expected config shape.

## Common Commands

Run all Swift tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
```

Build and print the app bundle path:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app --print-bundle-path
```

Build, ad-hoc sign, and launch the local app bundle:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app
```

Run a CLI transcription smoke test:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI \
  --config Config/speech-engine.json \
  --audio data/benchmarks/samples/en-001.wav \
  --mode auto
```

Check Harness story proof:

```bash
rtk ./scripts/bin/harness-cli query matrix
rtk ./scripts/bin/harness-cli story verify US-007
```

## Validation Notes

The automated MVP floor is the full Swift test suite. Platform validation adds:

- app launches as a background/accessory menu bar utility
- menu bar menu exposes state, permissions, shortcut, settings, and quit
- settings window opens from the menu bar
- global shortcut starts/stops recording after Input Monitoring approval
- overlay appears during recording/processing states
- focused-app paste works after Accessibility approval

When macOS TCC gets confused by rebuilt ad-hoc bundles, reset permissions for
the bundle identifier and relaunch:

```bash
tccutil reset ListenEvent dev.alevoice.AleVoiceApp
tccutil reset Accessibility dev.alevoice.AleVoiceApp
```

Then approve the permissions from System Settings when prompted.
