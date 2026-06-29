# Multi-Engine Language Selection Design

Date: 2026-06-29
Status: Proposed

## Goal

Support real hotkey dictation with:

- model selection
- language selection
- setup/install flow for multiple local FunASR-backed engines

The target user-facing choices are:

- Auto
- English
- Vietnamese

This must work for the real dictation path, not only sample/debug transcription.

## Current State

- The current shipping path is pinned to `funasr-sensevoice`.
- The app contract and code treat the MVP workflow as Auto-only.
- The config model already supports keyed `engines` and `selectedEngine`.
- The setup CLI already installs one managed engine from a committed manifest.
- The hotkey recording path currently ignores the view-model mode selection and
  always transcribes with `.auto`.

Relevant current constraints:

- `SpeechEngineSettings.validate()` enforces FunASR `defaultMode == .auto`.
- `FunASRSpeechEngine` rejects explicit modes.
- `ContentView` presents dictation as Auto-only.
- docs/product contract lists forced English/Vietnamese as out of scope.

## Product Decision

Start with one global active model.

- The app exposes one selected engine at a time.
- The app exposes one selected language mode at a time.
- The available language modes are filtered by the selected engine's
  capabilities.
- The real hotkey dictation path uses the selected engine and selected mode.

This is preferred over per-language routing because it is easier to explain,
test, and validate end to end.

## Engine Strategy

Add support for multiple managed local engines:

1. `funasr-sensevoice`
2. `funasr-nano`
3. `funasr-mlt-nano`

Intended capabilities:

- `funasr-sensevoice`
  - default path for low-friction local dictation
  - conservative capability surface: Auto-only until explicit mode support is
    proven in the pinned runtime
- `funasr-nano`
  - candidate engine for Auto, English, Vietnamese
  - installed through the same managed setup flow
  - current pinned `llama-funasr-cli` path is not good enough for Vietnamese
- `funasr-mlt-nano`
  - separate Vietnamese-capable path
  - uses CrispASR macOS runtime instead of the pinned `llama-funasr-cli`
  - pinned to a higher-quality MLT model quant that passes local smoke better

Validated runtime findings:

- The pinned `llama-funasr-cli` binary only exposes
  `--enc <encoder> -m <model> -a <audio>` and no explicit language flag.
- Local smoke on `vi-001.wav` confirms current `funasr-nano` should stay
  `auto`/`en` only.
- CrispASR's macOS binary exposes `-l <lang>` and `-l auto`.
- Local smoke on `Fun-ASR-MLT-Nano-2512` showed:
  - q4_k: Vietnamese still not acceptable
  - q8_0: English exact on `en-001.wav`, Vietnamese close on `vi-001.wav`

Therefore:

- keep `funasr-nano` as the current light-weight path
- do not expose `vi` on `funasr-nano`
- add `funasr-mlt-nano` as a separate engine with its own runtime profile
- pin `funasr-mlt-nano` to q8_0, not q4_k

## Setup CLI Design

Keep the manifest-driven setup architecture, but evolve it from single-engine
replace semantics to multi-engine merge semantics.

### Commands

Keep the current subcommand model:

- `AleVoiceCLI setup <engine-id>`
- `AleVoiceCLI doctor`
- `AleVoiceCLI transcribe`
- `AleVoiceCLI run`

### Help Text

CLI help and usage output must be updated to describe the multi-engine model:

- `setup` installs an engine into the managed AleVoice runtime
- repeated `setup` calls may add engines side-by-side instead of replacing the
  config
- `doctor` validates the selected engine and can report installed-engine state
- `transcribe` supports explicit mode requests subject to selected-engine
  capability

At minimum, help text should:

- list both supported engine ids when manifests exist
- describe that setup merges into `Config/speech-engine.json`
- describe the current mode vocabulary (`auto|en|vi`)
- avoid implying the app is permanently tied to SenseVoice

### Setup Flow

For `setup <engine-id>`:

1. Parse engine id and optional flags.
2. Load `Config/engines/<engine-id>.json`.
3. Resolve the current platform artifact.
4. Download runtime and model artifacts.
5. Verify checksums.
6. Install runtime and models into managed AleVoice directories.
7. Merge the installed engine entry into `Config/speech-engine.json`.
8. If no engine was selected before, set `selectedEngine` to the newly
   installed engine.
9. If no mode was selected before, set `selectedMode` to the installed engine's
   default mode.
10. Run doctor checks.

For `funasr-sensevoice`, setup installs:

- one runtime binary
- one primary model file

For `funasr-nano`, setup installs:

- one runtime binary
- one decoder model file
- one auxiliary encoder model file

For `funasr-mlt-nano`, setup installs:

- one CrispASR macOS runtime archive
- one `funasr-mlt-nano-2512-q8_0.gguf` model file

## Config Model

`Config/speech-engine.json` becomes the single source of truth for:

- installed engines
- selected engine
- selected mode
- per-engine capabilities

Proposed shape:

```json
{
  "selectedEngine": "funasr-nano",
  "selectedMode": "vi",
  "engines": {
    "funasr-sensevoice": {
      "engineKind": "funasr",
      "displayName": "FunASR SenseVoice",
      "binaryPath": ".../llama-funasr-sensevoice",
      "modelPath": ".../sensevoice-small-f16.gguf",
      "defaultMode": "auto",
      "supportedModes": ["auto"]
    },
    "funasr-nano": {
      "engineKind": "funasr",
      "displayName": "FunASR Nano",
      "binaryPath": ".../llama-funasr-cli",
      "modelPath": ".../qwen3-0.6b-q4km.gguf",
      "auxiliaryModelPaths": {
        "encoder": ".../funasr-encoder-f16.gguf"
      },
      "defaultMode": "auto",
      "supportedModes": ["auto", "en"]
    },
    "funasr-mlt-nano": {
      "engineKind": "funasr",
      "displayName": "FunASR MLT Nano",
      "binaryPath": ".../crispasr",
      "modelPath": ".../funasr-mlt-nano-2512-q8_0.gguf",
      "defaultMode": "auto",
      "supportedModes": ["auto", "en", "vi"],
      "runtimeProfile": "crispasrFunASR"
    }
  }
}
```

### Core Type Changes

`EngineInstallConfig` should gain:

- `displayName`
- `supportedModes: [SpeechLanguageMode]`
- `auxiliaryModelPaths: [String: String]?`
- `runtimeProfile`

`SpeechEngineSettings` should gain:

- `selectedMode: SpeechLanguageMode`

Legacy decode compatibility must remain:

- old config files without `selectedMode`
- old config files without `supportedModes`
- old single-engine shape

Legacy defaults should decode to the current SenseVoice Auto-only behavior so
existing users are not broken by the shape upgrade.

### Validation Rules

Config validation should enforce:

- `selectedEngine` exists in `engines`
- `selectedMode` is listed in the selected engine's `supportedModes`
- engine binary path is non-empty
- engine primary model path is non-empty
- engine-specific auxiliary model paths required by that engine exist in config

Validation should no longer enforce a global FunASR Auto-only rule.

## Runtime / Transcription Design

Retain a single high-level `SpeechEngine` abstraction, but allow command
building to vary by installed engine configuration.

### SenseVoice Path

Initial command shape remains:

```text
llama-funasr-sensevoice -m <model> -a <audio>
```

SenseVoice should continue to reject explicit modes until the pinned runtime
proves otherwise.

### Nano Path

Initial command shape is expected to be:

```text
llama-funasr-cli --enc <encoder> -m <decoder> -a <audio>
```

Forced language arguments must not be hardcoded until validated against the
installed binary's real help surface and smoke behavior.

### MLT Nano Path

Command shape:

```text
crispasr --backend fun-asr-mlt-nano -m <model> -f <audio> -l <auto|en|vi> -nt -np
```

Implementation choice:

- keep one top-level `FunASRSpeechEngine`
- branch command building on `runtimeProfile`
- keep the existing llama.cpp-style path for SenseVoice and Nano
- add a CrispASR profile for `funasr-mlt-nano`

This avoids inventing a second speech-engine abstraction when the only change
is process invocation shape.

Implementation should separate:

- engine capability metadata
- command construction
- runtime support proof

This keeps the app from exposing unsupported UI choices based only on optimistic
doc reading.

## App / UI Design

Add explicit controls for:

- selected model
- selected language

### Behavior

- model picker lists installed engines using `displayName`
- language picker lists only modes supported by the selected engine
- changing model may auto-adjust selected mode if the current mode is not
  supported by the new engine
- real hotkey dictation uses current `selectedEngine + selectedMode`
- sample transcription path should use the same selection logic for consistency

### Immediate User Experience Rule

The app must never present:

- Vietnamese as selectable when the selected engine cannot support it
- English/Vietnamese as selectable when runtime validation has not proven the
  engine path

### Product Doc Updates

The product contract will need updates because forced EN/VI is currently marked
out of scope. The new contract should reflect:

- multi-engine local setup
- selected model in settings
- selected language in settings
- actual supported-mode limits by installed engine

## Doctor / Diagnostics

`doctor` should evolve from selected-engine-only readiness checks toward
installed-engine-aware diagnostics.

At minimum:

- show selected engine id
- show selected mode
- verify binary/model readiness for the selected engine

Stretch improvement:

- print installed engine inventory
- print supported modes per installed engine
- print whether explicit mode validation was proven for that runtime

## Testing Strategy

### Unit

- `funasr-nano` manifest decode
- config merge behavior instead of overwrite
- legacy config migration
- selected engine/mode validation
- command building for SenseVoice and Nano
- engine capability filtering in UI/view model
- hotkey path propagation of selected engine/mode
- CLI help text and usage updates

### Integration

- `setup funasr-sensevoice` then `setup funasr-nano` keeps both engines in
  config
- selected engine switching changes transcription requests
- selected mode switching changes transcription requests when supported
- Nano install fails clearly when auxiliary model artifacts are missing
- doctor reports useful selected-engine state

### Manual / Platform

1. run real `setup funasr-sensevoice`
2. run real `setup funasr-nano`
3. verify both engines exist in config
4. inspect Nano binary help surface
5. smoke-test `transcribe --mode auto`
6. if binary supports it, smoke-test `transcribe --mode en`
7. if binary supports it, smoke-test `transcribe --mode vi`
8. validate live hotkey dictation with the chosen engine and mode

## Rollout Plan

1. multi-engine config + merge installer
2. Nano manifest and installer support
3. updated CLI help text and command docs
4. app settings model picker + filtered language picker
5. hotkey path uses selected engine/mode
6. explicit EN/VI exposure only after pinned Nano runtime proof

## Alternatives Considered

### Hardcode capabilities in app code

Rejected because setup/config and UI would drift.

### Per-language routing

Example:

- Auto -> SenseVoice
- English -> Nano
- Vietnamese -> Nano

Rejected for the first slice because it hides the active engine decision and
makes diagnosis harder.

### Separate config per model

Rejected because switching engines would require config rewriting and creates a
worse UX for a resident menu bar utility.

## Recommendation

Proceed with a normal story-sized implementation that introduces:

- side-by-side managed engine installs
- selected engine + selected mode in config
- model-aware language filtering in UI
- hotkey dictation wired to the selected engine/mode

Treat explicit Nano `en` / `vi` forcing as a guarded capability that must be
proven against the real pinned runtime before the UI advertises it.
