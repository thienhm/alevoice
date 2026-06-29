# Setup CLI Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a manifest-driven AleVoice setup CLI for the first managed engine, `funasr-sensevoice`, while preserving current app behavior and legacy config compatibility.

**Architecture:** Keep the app/core runtime contract in `AleVoiceCore`, move setup/install orchestration into focused `AleVoiceCLI` files, and drive provider-specific behavior from committed manifests under `Config/engines/`. Preserve the existing smoke transcription flow by renaming it to `transcribe` and mapping legacy root flags to that subcommand during a transition window.

**Tech Stack:** SwiftPM, Swift 6, Foundation, XCTest, repo-local shell script wrappers, JSON manifests.

---

### Task 1: Story And Contract Scaffolding

**Files:**
- Create: `docs/stories/epics/E01-local-stt/US-008-setup-cli/execplan.md`
- Create: `docs/stories/epics/E01-local-stt/US-008-setup-cli/overview.md`
- Create: `docs/stories/epics/E01-local-stt/US-008-setup-cli/design.md`
- Create: `docs/stories/epics/E01-local-stt/US-008-setup-cli/validation.md`
- Create: `docs/decisions/0008-manifest-driven-setup-cli.md`

- [ ] **Step 1: Confirm story and decision files exist**

Run: `rtk rg "US-008|0008 Manifest-Driven AleVoice Setup CLI" -n docs/stories docs/decisions`
Expected: matches for the new story packet and decision file.

- [ ] **Step 2: Record durable story metadata**

Run: `rtk scripts/bin/harness-cli story add --id US-008 --title "One-command setup CLI for FunASR SenseVoice" --lane high-risk`
Expected: story row created or already present.

- [ ] **Step 3: Record durable decision metadata**

Run: `rtk scripts/bin/harness-cli decision add --id 0008 --title "Manifest-Driven AleVoice Setup CLI" --doc docs/decisions/0008-manifest-driven-setup-cli.md`
Expected: decision row created or updated.

### Task 2: Config Evolution Under TDD

**Files:**
- Modify: `Sources/AleVoiceCore/SpeechEngineConfig.swift`
- Modify: `tests/AleVoiceCoreTests/SpeechEngineConfigTests.swift`
- Modify: `tests/AleVoiceCoreTests/AudioRecorderTests.swift`
- Modify: `tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift`

- [ ] **Step 1: Write failing config compatibility tests**

Add tests for:

```swift
func test_loadReadsNewSelectedEngineShape() throws
func test_loadNormalizesLegacyFunASRShapeIntoSelectedEngine() throws
func test_writePersistsNewSelectedEngineShape() throws
```

- [ ] **Step 2: Run targeted config tests to verify red**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SpeechEngineConfigTests`
Expected: FAIL because the new decode/encode helpers do not exist yet.

- [ ] **Step 3: Implement the minimal config migration model**

Add:

```swift
public struct SpeechEngineSettings: Equatable, Sendable {
    public let selectedEngineID: String
    public let engines: [String: EngineInstallConfig]
    public var selectedEngine: EngineInstallConfig { ... }
    public static func load(from url: URL) throws -> SpeechEngineSettings { ... }
    public func save(to url: URL) throws { ... }
}
```

Keep a compatibility accessor:

```swift
public var funasr: EnginePathConfig { selectedEngine.pathConfig }
```

- [ ] **Step 4: Re-run targeted config tests to verify green**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SpeechEngineConfigTests`
Expected: PASS.

### Task 3: Manifest Model And Parsing Under TDD

**Files:**
- Create: `Config/engines/funasr-sensevoice.json`
- Create: `Sources/AleVoiceCLI/SetupManifest.swift`
- Create: `tests/AleVoiceCoreTests/SetupManifestTests.swift`

- [ ] **Step 1: Write failing manifest tests**

Add tests for:

```swift
func test_loadsPinnedFunASRSenseVoiceManifest() throws
func test_resolvesMacOSArm64RuntimeArtifact() throws
func test_manifestRejectsMissingChecksum() throws
```

- [ ] **Step 2: Run targeted manifest tests to verify red**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupManifestTests`
Expected: FAIL because the manifest types/file do not exist yet.

- [ ] **Step 3: Add the manifest file and decode types**

Use pinned provider data:

- runtime URL: `https://github.com/modelscope/FunASR/releases/download/runtime-llamacpp-v0.1.2/funasr-llamacpp-macos-arm64.tar.gz`
- runtime digest: `50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923`
- model URL: `https://huggingface.co/FunAudioLLM/SenseVoiceSmall-GGUF/resolve/main/sensevoice-small-f16.gguf`
- model digest: `2389039651f4574dbd674f1f1e296b8b1147b2e19a5fd9c2cd69e82669c78d8e`

- [ ] **Step 4: Re-run targeted manifest tests to verify green**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupManifestTests`
Expected: PASS.

### Task 4: Setup Installer Pipeline Under TDD

**Files:**
- Create: `Sources/AleVoiceCLI/SetupInstaller.swift`
- Create: `tests/AleVoiceCoreTests/SetupInstallerTests.swift`

- [ ] **Step 1: Write failing installer tests**

Add tests for:

```swift
func test_setupInstallsRuntimeAndModelWritesConfigAndRunsDoctor() throws
func test_setupFailsOnChecksumMismatchBeforeInstall() throws
func test_setupMarksRuntimeExecutableAfterUnpack() throws
```

- [ ] **Step 2: Run targeted installer tests to verify red**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupInstallerTests`
Expected: FAIL because installer abstractions do not exist yet.

- [ ] **Step 3: Implement minimal installer collaborators**

Add small protocols:

```swift
protocol ArtifactDownloading { func download(from: URL, to: URL) throws }
protocol ArchiveExtracting { func extractTarGzip(at: URL, to: URL) throws }
protocol SHA256Hashing { func digest(of fileURL: URL) throws -> String }
```

Installer responsibilities:

- create install layout
- download artifacts
- validate digests
- unpack runtime
- copy model
- `chmod +x` runtime
- write config
- call doctor

- [ ] **Step 4: Re-run targeted installer tests to verify green**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter SetupInstallerTests`
Expected: PASS.

### Task 5: CLI Surface Under TDD

**Files:**
- Modify: `Sources/AleVoiceCLI/main.swift`
- Create: `Sources/AleVoiceCLI/CLICommandParser.swift`
- Create: `Sources/AleVoiceCLI/Doctor.swift`
- Modify: `tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift`

- [ ] **Step 1: Write failing CLI command tests**

Add tests for:

```swift
func test_cliHelpPrintsSubcommandUsage() throws
func test_cliMapsLegacyRootFlagsToTranscribe() throws
func test_cliSetupRunsInstallerForKnownEngine() throws
func test_cliDoctorReportsMissingConfig() throws
func test_cliRunInvokesRepoLauncher() throws
```

- [ ] **Step 2: Run targeted CLI tests to verify red**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionCoordinatorTests`
Expected: FAIL because the subcommand parser and handlers do not exist yet.

- [ ] **Step 3: Implement the minimal subcommand runner**

Expose:

```swift
enum CLICommand
struct CLIContext
enum AleVoiceCLIProgram { static func run(arguments: [String], ...) -> Int32 }
```

Support:

- `setup funasr-sensevoice`
- `doctor`
- `transcribe`
- legacy `--config ... --audio ...`
- `run`

- [ ] **Step 4: Re-run targeted CLI tests to verify green**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionCoordinatorTests`
Expected: PASS.

### Task 6: Docs And End-To-End Verification

**Files:**
- Modify: `README.md`
- Modify: `Config/speech-engine.example.json`
- Modify: `docs/product/local-dictation-workflow.md`

- [ ] **Step 1: Update docs for the one-command flow**

Document:

- `swift run AleVoiceCLI setup funasr-sensevoice`
- managed install root
- `doctor`
- `transcribe`
- why runtime/model stay outside the app bundle

- [ ] **Step 2: Run the full Swift suite**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
Expected: PASS.

- [ ] **Step 3: Run CLI verification commands**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI doctor
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift run AleVoiceCLI transcribe --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto
```

Expected:

- `doctor` returns a clear pass/fail summary.
- `transcribe` succeeds when a valid local config exists.

- [ ] **Step 4: Update durable story proof**

Run:

```bash
rtk scripts/bin/harness-cli story update --id US-008 --status implemented --unit 1 --integration 1 --e2e 0 --platform 0
```

Expected: story proof fields updated.
