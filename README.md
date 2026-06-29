# AleVoice

AleVoice is a local macOS dictation utility for speaking text into other apps.
It records while a configured global shortcut is held, transcribes locally
through the current FunASR-first speech engine path, applies small formatting
commands, and pastes the result into the focused text field.

The current MVP is a resident menu bar app with a settings/debug window for
permissions, shortcut setup, sample transcription, and local diagnostics.

## Status

AleVoice is currently an alpha, source-first macOS app. The supported
distribution path today is:

- clone the repository
- point the app at a local FunASR runtime and model
- build and run the local app bundle on macOS

Signed, notarized drag-and-drop releases are not available yet.

## Quick Start For Alpha Testers

1. Clone the repository:

```bash
git clone https://github.com/thienhm/alevoice.git
cd alevoice
```

2. Make sure Xcode command line tools are installed:

```bash
xcode-select -p
```

If that command fails, install them with:

```bash
xcode-select --install
```

3. Install at least one local speech engine:

```bash
swift run AleVoiceCLI setup funasr-sensevoice
```

Optionally add Nano side-by-side:

```bash
swift run AleVoiceCLI setup funasr-nano
```

For Vietnamese-capable MLT Nano, add the larger CrispASR-backed engine:

```bash
swift run AleVoiceCLI setup funasr-mlt-nano
```

Each setup command will:

- download the pinned FunASR runtime and engine model artifacts
- verify checksums
- install them under `~/Library/Application Support/AleVoice/`
- merge the installed engine into `Config/speech-engine.json`
- run `doctor` at the end

4. Build the app:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI build
```

5. Launch the already-built app:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI run
```

6. Approve the macOS permissions the app needs:

- Microphone
- Accessibility
- Input Monitoring

Once launched, AleVoice runs as a menu bar app. Open the settings/debug window
from the menu bar to inspect permission state, record a shortcut, and run the
sample transcription path.

## Current MVP Contract

- Runs locally on macOS 14 or newer.
- Lives in the menu bar as a resident utility.
- Lets the user choose an installed local model and a supported language mode.
  The current pinned Nano GGUF setup exposes `auto` and `en`; the
  CrispASR-backed MLT Nano setup exposes `auto`, `en`, and `vi`.
- Records while the configured shortcut is held.
- Transcribes after release through the configured local FunASR runtime.
- Normalizes a small English/Vietnamese formatting command set.
- Pastes successful recording transcripts with clipboard-backed `Cmd+V`.
- Shows recording state through the menu bar waveform icon and keeps error text
  accessible from the menu/settings surfaces.
- Keeps sample-audio transcription display-only.

Caret-relative overlay placement, notarized packaging, and installer polish are
intentionally out of scope for the current MVP. Explicit language choices still
depend on the pinned runtime/model surface; AleVoice only exposes modes declared
by the installed engine config.

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
- Managed AleVoice runtime/model install under `~/Library/Application Support/AleVoice/`
- Microphone, Input Monitoring, and Accessibility permission for the signed app
  bundle when validating the full dictation/paste path

`Config/speech-engine.example.json` shows the expected config shape.

For Codex agent work in this repo, shell examples are usually shown with `rtk`.
For a normal local terminal, run the same commands without the `rtk` prefix.

## Common Commands

Run all Swift tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Build and print the app bundle path:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/run-alevoice-app --print-bundle-path
```

The local development app bundle is written to `build/AleVoice.app` so it is
visible in Finder and can be selected in macOS Privacy & Security permission
pickers. SwiftPM build products still live under `.build/`.

Build and ad-hoc sign the local app bundle:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI build
```

Run the already-built local app bundle:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI run
```

Or build, sign, and launch in one step:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/run-alevoice-app
```

Run a CLI transcription smoke test:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI \
  transcribe \
  --config Config/speech-engine.json \
  --audio data/benchmarks/samples/en-001.wav \
  --mode auto
```

Inspect multi-engine CLI help:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI --help
```

Check the current setup state:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run AleVoiceCLI doctor
```

`doctor` now reports:

- selected engine id and selected language mode
- every installed engine with display name, supported modes, default mode, and runtime profile
- binary/model/auxiliary-model presence for each installed engine
- sample audio presence and sample transcription result for the selected engine

For Codex/agent work, the equivalent commands are:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app
```

AleVoice does not bundle the FunASR runtime or model inside the app bundle in
this alpha. Those artifacts are large, third-party, updated independently, and
downloaded through the explicit setup command so the trust boundary stays
visible and checksum-verified.

Check Harness story proof when the Harness CLI is installed locally:

```bash
./scripts/bin/harness-cli query matrix
./scripts/bin/harness-cli story verify US-007
```

## Validation Notes

The automated MVP floor is the full Swift test suite. Platform validation adds:

- app launches as a background/accessory menu bar utility
- menu bar menu exposes state, enabled toggle, shortcut, settings, and quit
- settings window opens from the menu bar
- global shortcut starts/stops recording after Input Monitoring approval
- menu bar waveform icon turns red while recording
- focused-app paste works after Accessibility approval

When macOS TCC gets confused by rebuilt ad-hoc bundles, reset permissions for
the bundle identifier and relaunch:

```bash
tccutil reset ListenEvent dev.thienhuynh.alevoice
tccutil reset Accessibility dev.thienhuynh.alevoice
```

Then approve the permissions from System Settings when prompted.
