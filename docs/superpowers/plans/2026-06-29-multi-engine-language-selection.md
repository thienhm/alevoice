# Multi-Engine Language Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add side-by-side FunASR engine installs, model-aware language selection, and hotkey dictation using the selected model/mode.

**Architecture:** Keep the existing Swift package boundaries. Extend core config as the source of installed engine capabilities, extend setup manifests/install to merge engines and support Nano's two-model layout, then surface selected model/mode in the SwiftUI settings view and hotkey flow. Forced Nano `en`/`vi` command flags stay guarded until the pinned runtime proves support; this implementation exposes only capabilities declared in config/manifest.

**Tech Stack:** Swift Package Manager, XCTest, SwiftUI, local JSON config, FunASR llama.cpp/GGUF runtime manifests.

---

## File Map

- `Sources/AleVoiceCore/SpeechEngine.swift`: language mode display text.
- `Sources/AleVoiceCore/SpeechEngineConfig.swift`: selected mode, display names, supported modes, auxiliary model paths, selected engine helpers.
- `Sources/AleVoiceCore/FunASRSpeechEngine.swift`: SenseVoice and Nano command construction from engine config.
- `Sources/AleVoiceCore/TranscriptionCoordinator.swift`: pass selected engine config into engine factory and default to selected mode.
- `Sources/AleVoiceCLI/SetupManifest.swift`: manifest fields for display name, supported modes, auxiliary models.
- `Sources/AleVoiceCLI/SetupInstaller.swift`: install all model artifacts, merge config instead of replacing it.
- `Sources/AleVoiceCLI/Doctor.swift`: selected engine/mode diagnostics and auxiliary model checks.
- `Sources/AleVoiceCLI/CLIProgram.swift`: help text, setup output, transcribe default selected mode.
- `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`: installed engines, selected engine/mode filtering, hotkey selected mode.
- `Sources/AleVoiceAppUI/ContentView.swift`: model picker and filtered language picker.
- `Sources/AleVoiceApp/AleVoiceApp.swift`: load config capabilities into view model.
- `Config/engines/funasr-sensevoice.json`: add display/capability fields.
- `Config/engines/funasr-nano.json`: new Nano manifest.
- `Config/speech-engine.example.json`: updated multi-engine shape.
- `docs/product/local-dictation-workflow.md`: product contract update.
- Tests under `tests/AleVoiceCoreTests/` and `tests/AleVoiceAppUITests/`.

## Task 1: Core Config Capabilities

**Files:**
- Modify: `Sources/AleVoiceCore/SpeechEngine.swift`
- Modify: `Sources/AleVoiceCore/SpeechEngineConfig.swift`
- Test: `tests/AleVoiceCoreTests/SpeechEngineConfigTests.swift`

- [ ] **Step 1: Write failing config tests**

Add tests proving:

```swift
func test_loadReadsSelectedModeAndSupportedModes() throws
func test_loadRejectsSelectedModeUnsupportedBySelectedEngine() throws
func test_legacyShapeDefaultsToAutoOnlySupport() throws
func test_savePersistsSelectedModeAndCapabilities() throws
```

Expected behavior:

- decoded config can include `selectedMode`, `displayName`, `supportedModes`, and `auxiliaryModelPaths`
- `selectedMode` must be supported by selected engine
- legacy config decodes as Auto-only
- save persists new fields

- [ ] **Step 2: Run RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SpeechEngineConfigTests
```

Expected: FAIL because new fields/helpers do not exist.

- [ ] **Step 3: Implement config types**

Implement:

```swift
public enum SpeechLanguageMode {
    public var displayName: String {
        switch self {
        case .auto: "Auto"
        case .en: "English"
        case .vi: "Vietnamese"
        }
    }
}
```

Extend `EnginePathConfig` and `EngineInstallConfig` with:

```swift
displayName: String
supportedModes: [SpeechLanguageMode]
auxiliaryModelPaths: [String: String]
```

Extend `SpeechEngineSettings` with:

```swift
selectedMode: SpeechLanguageMode
selectedEngineConfig: EngineInstallConfig
selectedPathConfig: EnginePathConfig
availableEngines: [(id: String, config: EngineInstallConfig)]
```

Validation:

- selected engine exists
- selected mode is supported by selected engine
- binary/model non-empty
- if `auxiliaryModelPaths["encoder"]` is present it must be non-empty

- [ ] **Step 4: Run GREEN**

Run same filtered test. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/AleVoiceCore/SpeechEngine.swift Sources/AleVoiceCore/SpeechEngineConfig.swift tests/AleVoiceCoreTests/SpeechEngineConfigTests.swift
rtk git commit -m "feat: add engine language capabilities"
```

## Task 2: Setup Manifest, Merge Installer, Nano Manifest

**Files:**
- Modify: `Sources/AleVoiceCLI/SetupManifest.swift`
- Modify: `Sources/AleVoiceCLI/SetupInstaller.swift`
- Modify: `Config/engines/funasr-sensevoice.json`
- Create: `Config/engines/funasr-nano.json`
- Test: `tests/AleVoiceCoreTests/SetupManifestTests.swift`
- Test: `tests/AleVoiceCoreTests/SetupInstallerTests.swift`

- [ ] **Step 1: Write failing setup tests**

Add tests proving:

```swift
func test_loadsPinnedFunASRNanoManifest() throws
func test_setupMergesSecondEngineIntoExistingConfig() throws
func test_setupInstallsAuxiliaryNanoEncoderModel() throws
```

Expected behavior:

- Nano manifest decodes with `llama-funasr-cli`
- existing `funasr-sensevoice` config survives after installing `funasr-nano`
- Nano installs primary decoder and auxiliary encoder model

- [ ] **Step 2: Run RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupManifestTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupInstallerTests
```

Expected: FAIL because Nano manifest and merge install do not exist.

- [ ] **Step 3: Implement manifest and installer**

Add manifest fields:

```swift
let supportedModes: [SpeechLanguageMode]
let displayName: String?
let auxiliaryModels: [String: SetupModelArtifact]
```

Installer behavior:

- download and verify every model artifact
- copy primary model to `modelPath`
- copy auxiliary models and store their installed paths in `auxiliaryModelPaths`
- load existing config if present
- merge/replace only the installed engine id
- preserve previous `selectedEngine`/`selectedMode` when still valid
- select newly installed engine only when no valid selected engine exists

Create `Config/engines/funasr-nano.json` using pinned runtime v0.1.3 macOS arm64 and `Fun-ASR-Nano-GGUF` q4km decoder + f16 encoder artifacts.

- [ ] **Step 4: Run GREEN**

Run same setup tests. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/AleVoiceCLI/SetupManifest.swift Sources/AleVoiceCLI/SetupInstaller.swift Config/engines/funasr-sensevoice.json Config/engines/funasr-nano.json tests/AleVoiceCoreTests/SetupManifestTests.swift tests/AleVoiceCoreTests/SetupInstallerTests.swift
rtk git commit -m "feat: add multi-engine setup manifests"
```

## Task 3: Runtime Commands, Coordinator, CLI Help

**Files:**
- Modify: `Sources/AleVoiceCore/FunASRSpeechEngine.swift`
- Modify: `Sources/AleVoiceCore/TranscriptionCoordinator.swift`
- Modify: `Sources/AleVoiceCLI/Doctor.swift`
- Modify: `Sources/AleVoiceCLI/CLIProgram.swift`
- Test: `tests/AleVoiceCoreTests/FunASRSpeechEngineTests.swift`
- Test: `tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift`

- [ ] **Step 1: Write failing runtime/CLI tests**

Add tests proving:

```swift
func test_buildCommandUsesNanoEncoderAndDecoder() throws
func test_transcribeUsesSelectedModeWhenOverrideIsNil() throws
func test_cliHelpMentionsMultiEngineSetupAndModes()
func test_cliTranscribeUsesSelectedConfigModeWhenModeOmitted()
func test_doctorReportsSelectedModeAndAuxiliaryModel() throws
```

- [ ] **Step 2: Run RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter FunASRSpeechEngineTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionCoordinatorTests
```

Expected: FAIL.

- [ ] **Step 3: Implement runtime/CLI**

Runtime:

- SenseVoice command remains `binary -m model -a audio`
- Nano command is `binary --enc encoder -m decoder -a audio`
- explicit non-auto modes are allowed only when `supportedModes` declares them; no language flag is appended until real CLI flag proof exists

Coordinator:

- factory receives selected `EnginePathConfig`
- nil override uses `settings.selectedMode`

CLI:

- help lists `funasr-sensevoice`, `funasr-nano`, `auto|en|vi`
- transcribe with no `--mode` uses config `selectedMode`
- setup output says config is merged

- [ ] **Step 4: Run GREEN**

Run same filtered tests. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/AleVoiceCore/FunASRSpeechEngine.swift Sources/AleVoiceCore/TranscriptionCoordinator.swift Sources/AleVoiceCLI/Doctor.swift Sources/AleVoiceCLI/CLIProgram.swift tests/AleVoiceCoreTests/FunASRSpeechEngineTests.swift tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift
rtk git commit -m "feat: route transcription by selected engine mode"
```

## Task 4: App UI and Hotkey Selection

**Files:**
- Modify: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Test: `tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift`
- Test: `tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift`

- [ ] **Step 1: Write failing UI/hotkey tests**

Replace the current Auto-only tests with:

```swift
func test_stopRecordingUsesSelectedModeForRecordingFlow() async throws
func test_hotkeyReleaseUsesSelectedMode() async throws
func test_selectingEngineFiltersUnsupportedMode() async throws
func test_modeOptionsFollowSelectedEngine() async throws
```

- [ ] **Step 2: Run RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionDebugViewModelTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter GlobalHotkeyDebugViewModelTests
```

Expected: FAIL.

- [ ] **Step 3: Implement view model and UI**

View model:

- load installed engine options from config
- expose `selectedEngineID`, `selectedMode`, `availableLanguageModes`
- when selected engine changes, keep mode if supported or reset to engine default
- recording flow passes selected mode
- hotkey release calls recording flow with selected mode

Content view:

- replace `Text("Dictation mode: Auto")`
- add Picker for model
- add Picker for language
- disable controls while recording/running/capturing shortcut

App:

- on startup, load `SpeechEngineSettings` from config if possible and seed view-model options

- [ ] **Step 4: Run GREEN**

Run same UI tests. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift Sources/AleVoiceAppUI/ContentView.swift Sources/AleVoiceApp/AleVoiceApp.swift tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift
rtk git commit -m "feat: select dictation model and language"
```

## Task 5: Docs and Full Verification

**Files:**
- Modify: `Config/speech-engine.example.json`
- Modify: `README.md`
- Modify: `docs/product/local-dictation-workflow.md`

- [ ] **Step 1: Update docs**

Document:

- `setup funasr-sensevoice`
- `setup funasr-nano`
- side-by-side config merge
- selected model/mode behavior
- Nano explicit EN/VI still requires pinned runtime proof before claiming forced language flags

- [ ] **Step 2: Run full verification**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI --help
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI doctor
```

Expected:

- tests pass
- help shows multi-engine setup
- doctor may fail locally if config/runtime absent, but output must be clear

- [ ] **Step 3: Commit**

```bash
rtk git add Config/speech-engine.example.json README.md docs/product/local-dictation-workflow.md
rtk git commit -m "docs: document multi-engine language selection"
```

- [ ] **Step 4: Final status**

Run:

```bash
rtk git status --short
```

Expected: clean worktree.
