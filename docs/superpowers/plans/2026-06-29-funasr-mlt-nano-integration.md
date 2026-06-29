# FunASR MLT Nano Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a separate `funasr-mlt-nano` engine using CrispASR so AleVoice can offer `auto`, `en`, and `vi` on the real dictation path.

**Architecture:** Extend the existing FunASR config/install model with a `runtimeProfile`, add one new manifest for CrispASR + MLT Nano Q8, and teach `FunASRSpeechEngine` to build either the legacy llama.cpp command or the CrispASR command. Keep UI selection logic unchanged except for the extra installed engine metadata.

**Tech Stack:** SwiftPM, Swift XCTest, manifest-driven setup JSON, CrispASR macOS release artifact, Hugging Face GGUF model.

---

### Task 1: Runtime-profile config plumbing

**Files:**
- Modify: `Sources/AleVoiceCore/SpeechEngineConfig.swift`
- Test: `tests/AleVoiceCoreTests/SpeechEngineConfigTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func test_loadReadsRuntimeProfileForManagedEngine() throws {
    let url = makeTempConfigURL()
    try """
    {
      "selectedEngine": "funasr-mlt-nano",
      "selectedMode": "vi",
      "engines": {
        "funasr-mlt-nano": {
          "engineKind": "funasr",
          "displayName": "FunASR MLT Nano",
          "binaryPath": "/tmp/crispasr",
          "modelPath": "/tmp/funasr-mlt.gguf",
          "defaultMode": "auto",
          "supportedModes": ["auto", "en", "vi"],
          "runtimeProfile": "crispasrFunASR"
        }
      }
    }
    """.write(to: url, atomically: true, encoding: .utf8)

    let settings = try SpeechEngineSettings.load(from: url)

    XCTAssertEqual(settings.selectedEngineConfig.runtimeProfile, .crispASRFunASR)
    XCTAssertEqual(settings.selectedPathConfig.runtimeProfile, .crispASRFunASR)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SpeechEngineConfigTests/test_loadReadsRuntimeProfileForManagedEngine`
Expected: FAIL because `runtimeProfile` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
public enum FunASRRuntimeProfile: String, Codable, Equatable, Sendable {
    case llamaCPP = "llamaCpp"
    case crispASRFunASR = "crispasrFunASR"
}

public struct EnginePathConfig: Codable, Equatable, Sendable {
    public let runtimeProfile: FunASRRuntimeProfile
    ...
}

public struct EngineInstallConfig: Codable, Equatable, Sendable {
    public let runtimeProfile: FunASRRuntimeProfile
    ...
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SpeechEngineConfigTests/test_loadReadsRuntimeProfileForManagedEngine`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/AleVoiceCore/SpeechEngineConfig.swift tests/AleVoiceCoreTests/SpeechEngineConfigTests.swift
rtk git commit -m "Add FunASR runtime profiles"
```

### Task 2: Manifest + installer support for MLT Nano

**Files:**
- Create: `Config/engines/funasr-mlt-nano.json`
- Modify: `Sources/AleVoiceCLI/SetupManifest.swift`
- Modify: `Sources/AleVoiceCLI/SetupInstaller.swift`
- Test: `tests/AleVoiceCoreTests/SetupManifestTests.swift`
- Test: `tests/AleVoiceCoreTests/SetupInstallerTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func test_loadsPinnedFunASRMLTNanoManifest() throws
func test_setupInstallsMLTNanoAndPersistsRuntimeProfile() throws
```

Key assertions:

```swift
XCTAssertEqual(manifest.id, "funasr-mlt-nano")
XCTAssertEqual(variant.configTemplate.supportedModes, [.auto, .en, .vi])
XCTAssertEqual(variant.configTemplate.runtimeProfile, .crispASRFunASR)
XCTAssertEqual(saved.selectedEngineConfig.runtimeProfile, .crispASRFunASR)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupManifestTests/test_loadsPinnedFunASRMLTNanoManifest`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupInstallerTests/test_setupInstallsMLTNanoAndPersistsRuntimeProfile`

Expected: FAIL because manifest/profile support is missing.

- [ ] **Step 3: Write minimal implementation**

```json
{
  "id": "funasr-mlt-nano",
  "displayName": "FunASR MLT Nano",
  "engineKind": "funasr",
  "defaultVariant": "default",
  "variants": {
    "default": {
      "runtime": {
        "platforms": {
          "macos-arm64": {
            "url": "https://github.com/CrispStrobe/CrispASR/releases/download/v0.8.5/crispasr-macos.tar.gz",
            "sha256": "6b01588c4833b419d562229a3a3dcba597105ba97d9e1f09974bb43b85d5be82"
          }
        },
        "unpack": "tar.gz",
        "binaryRelativePath": "crispasr-macos/crispasr"
      },
      "models": [
        {
          "id": "funasr-mlt-nano-q8_0",
          "url": "https://huggingface.co/cstr/funasr-mlt-nano-GGUF/resolve/main/funasr-mlt-nano-2512-q8_0.gguf",
          "sha256": "29d9ccaea032650bc747a33947f65f940bcbcf019d9f11471e4e8e0d7bab1b04",
          "relativePath": "funasr-mlt-nano-2512-q8_0.gguf"
        }
      ],
      "configTemplate": {
        "defaultMode": "auto",
        "supportedModes": ["auto", "en", "vi"],
        "runtimeProfile": "crispasrFunASR"
      }
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupManifestTests/test_loadsPinnedFunASRMLTNanoManifest`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupInstallerTests/test_setupInstallsMLTNanoAndPersistsRuntimeProfile`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
rtk git add Config/engines/funasr-mlt-nano.json Sources/AleVoiceCLI/SetupManifest.swift Sources/AleVoiceCLI/SetupInstaller.swift tests/AleVoiceCoreTests/SetupManifestTests.swift tests/AleVoiceCoreTests/SetupInstallerTests.swift
rtk git commit -m "Add FunASR MLT Nano setup manifest"
```

### Task 3: CrispASR command building

**Files:**
- Modify: `Sources/AleVoiceCore/FunASRSpeechEngine.swift`
- Test: `tests/AleVoiceCoreTests/FunASRSpeechEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func test_buildCommandUsesCrispASRProfileForExplicitVietnamese() throws
func test_buildCommandUsesCrispASRProfileForAutoMode() throws
```

Expected command:

```swift
[
    "/tmp/crispasr",
    "--backend", "fun-asr-mlt-nano",
    "-m", "/tmp/funasr-mlt.gguf",
    "-f", "/tmp/vi-001.wav",
    "-l", "vi",
    "-nt",
    "-np",
]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter FunASRSpeechEngineTests/test_buildCommandUsesCrispASRProfileForExplicitVietnamese`
Expected: FAIL because current builder only knows llama.cpp shape.

- [ ] **Step 3: Write minimal implementation**

```swift
switch config.runtimeProfile {
case .llamaCPP:
    ...
case .crispASRFunASR:
    return [
        config.binaryPath,
        "--backend", "fun-asr-mlt-nano",
        "-m", config.modelPath,
        "-f", request.audioURL.path,
        "-l", request.mode.rawValue,
        "-nt",
        "-np",
    ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter FunASRSpeechEngineTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/AleVoiceCore/FunASRSpeechEngine.swift tests/AleVoiceCoreTests/FunASRSpeechEngineTests.swift
rtk git commit -m "Teach FunASR engine to run CrispASR MLT"
```

### Task 4: CLI/help/config fixtures + docs

**Files:**
- Modify: `Sources/AleVoiceCLI/CLIProgram.swift`
- Modify: `Config/speech-engine.example.json`
- Modify: `README.md`
- Modify: `docs/product/local-dictation-workflow.md`
- Modify: `docs/stories/epics/E01-local-stt/US-009-multi-engine-language-selection.md`
- Test: `tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift`
- Test: `tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift`
- Test: `tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Add assertions that help text lists `setup funasr-mlt-nano` and that fixtures can persist/read an engine with `supportedModes: [.auto, .en, .vi]`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionCoordinatorTests/test_cliRunPrintsUsageAndExitsZeroForHelp`
Expected: FAIL because help text omits the new engine.

- [ ] **Step 3: Write minimal implementation**

```swift
setup funasr-mlt-nano [--config-path <path>] [--install-root <path>] [--force-download]
```

Docs should say:

- current `funasr-nano` remains `auto/en`
- `funasr-mlt-nano` is the Vietnamese-capable path
- pinned model is Q8 because local q4 smoke was not good enough

- [ ] **Step 4: Run tests to verify they pass**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionCoordinatorTests`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionDebugViewModelTests`

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter GlobalHotkeyDebugViewModelTests`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/AleVoiceCLI/CLIProgram.swift Config/speech-engine.example.json README.md docs/product/local-dictation-workflow.md docs/stories/epics/E01-local-stt/US-009-multi-engine-language-selection.md tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift
rtk git commit -m "Document FunASR MLT Nano engine"
```

### Task 5: Full verification + local smoke

**Files:**
- Modify: `Config/speech-engine.json` (only if needed for local smoke)

- [ ] **Step 1: Run focused regression suite**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupManifestTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupInstallerTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter FunASRSpeechEngineTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SpeechEngineConfigTests
```

Expected: all PASS

- [ ] **Step 2: Run full suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
Expected: PASS with 0 failures

- [ ] **Step 3: Run CLI help + real local smoke**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI --help
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI setup funasr-mlt-nano --force-download
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI transcribe --config Config/speech-engine.json --audio data/benchmarks/samples/vi-001.wav --mode vi
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI transcribe --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode en
```

Expected:

- help includes `setup funasr-mlt-nano`
- setup succeeds
- Vietnamese transcript is materially closer to `mo terminal va hien thi git status` than the old Nano output
- English transcript contains `Open terminal and show git status.`

- [ ] **Step 4: Commit final polish**

```bash
rtk git add -A
rtk git commit -m "Add CrispASR-backed FunASR MLT Nano engine"
```
