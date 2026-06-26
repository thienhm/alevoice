# FunASR-First Native Transcription Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build first macOS-native transcription slice that routes local audio files through FunASR behind a pluggable speech engine boundary, then exposes transcript and latency through a CLI smoke runner and minimal debug UI.

**Architecture:** Start with a Swift Package that contains reusable speech-core types plus two thin surfaces: `AleVoiceCLI` for deterministic smoke validation and `AleVoiceApp` for a small native debug shell. Keep engine selection centralized in JSON config and isolate all process spawning, argument building, and stdout parsing inside `FunASRSpeechEngine` so `whisper.cpp` can later slot into same coordinator without rewriting app flow.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI for debug shell, Foundation `Process`, XCTest, local FunASR GGUF runtime, existing benchmark sample audio.

---

## File Structure

- Create `Package.swift` for `AleVoiceCore` library and tests.
- Create `Config/speech-engine.example.json` for engine selection and local runtime paths.
- Modify `.gitignore` to keep local `Config/speech-engine.json` out of git.
- Create `Sources/AleVoiceCore/SpeechEngine.swift` for shared request/result/error types and protocol boundary.
- Create `Sources/AleVoiceCore/SpeechEngineConfig.swift` for JSON-backed engine settings loading.
- Create `Sources/AleVoiceCore/ProcessRunning.swift` for mockable process execution.
- Create `Sources/AleVoiceCore/FunASRSpeechEngine.swift` for FunASR-specific command building, stdout parsing, and transcription.
- Create `Sources/AleVoiceCore/TranscriptionCoordinator.swift` for config-driven engine construction and high-level request handling.
- Create `Sources/AleVoiceCLI/main.swift` for smoke-runner entrypoint.
- Create `Sources/AleVoiceApp/AleVoiceApp.swift` for minimal app bootstrap executable.
- Create `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift` for UI state and task orchestration.
- Create `Sources/AleVoiceAppUI/ContentView.swift` for small debug surface.
- Create `Tests/AleVoiceCoreTests/SpeechEngineConfigTests.swift` for config loading and validation.
- Create `Tests/AleVoiceCoreTests/FunASRSpeechEngineTests.swift` for command and parsing behavior.
- Create `Tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift` for engine selection and result mapping.
- Create `Tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift` for UI-facing state transitions.
- Create `docs/validation/us-002-funasr-first-native-transcription-core.md` for implementation proof.
- Modify `docs/stories/epics/E01-local-stt/US-002-funasr-first-native-transcription-core.md` after validation exists.

### Task 1: Scaffold Swift Package And Engine Settings

**Files:**
- Create: `Package.swift`
- Create: `Config/speech-engine.example.json`
- Modify: `.gitignore`
- Create: `Sources/AleVoiceCore/SpeechEngine.swift`
- Create: `Sources/AleVoiceCore/SpeechEngineConfig.swift`
- Test: `Tests/AleVoiceCoreTests/SpeechEngineConfigTests.swift`

- [ ] **Step 1: Write failing config tests**

```swift
import XCTest
@testable import AleVoiceCore

final class SpeechEngineConfigTests: XCTestCase {
    func test_loadDefaultsToFunASR() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine.json")
        try """
        {
          "engine": "funasr",
          "funasr": {
            "binaryPath": "/tmp/funasr",
            "modelPath": "/tmp/funasr.gguf",
            "defaultMode": "auto"
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        let settings = try SpeechEngineSettings.load(from: url)

        XCTAssertEqual(settings.engine, .funasr)
        XCTAssertEqual(settings.funasr.binaryPath, "/tmp/funasr")
        XCTAssertEqual(settings.funasr.defaultMode, .auto)
    }

    func test_loadRejectsMissingSelectedEngineBinaryPath() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-bad.json")
        try """
        {
          "engine": "funasr",
          "funasr": {
            "binaryPath": "",
            "modelPath": "/tmp/funasr.gguf",
            "defaultMode": "vi"
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SpeechEngineSettings.load(from: url))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SpeechEngineConfigTests`
Expected: FAIL with `no such module 'AleVoiceCore'` or missing `SpeechEngineSettings`.

- [ ] **Step 3: Write package scaffold, shared types, and config loader**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AleVoice",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AleVoiceCore", targets: ["AleVoiceCore"]),
    ],
    targets: [
        .target(name: "AleVoiceCore"),
        .testTarget(name: "AleVoiceCoreTests", dependencies: ["AleVoiceCore"]),
    ]
)
```

```swift
// Sources/AleVoiceCore/SpeechEngine.swift
import Foundation

public enum SpeechEngineKind: String, Codable {
    case funasr
    case whispercpp
}

public enum SpeechLanguageMode: String, Codable {
    case auto
    case en
    case vi
}

public struct SpeechTranscriptionRequest: Equatable {
    public let audioURL: URL
    public let mode: SpeechLanguageMode

    public init(audioURL: URL, mode: SpeechLanguageMode) {
        self.audioURL = audioURL
        self.mode = mode
    }
}

public struct SpeechTranscriptionResult: Equatable {
    public let engine: SpeechEngineKind
    public let modelIdentifier: String
    public let transcript: String
    public let latencyMs: Int

    public init(engine: SpeechEngineKind, modelIdentifier: String, transcript: String, latencyMs: Int) {
        self.engine = engine
        self.modelIdentifier = modelIdentifier
        self.transcript = transcript
        self.latencyMs = latencyMs
    }
}

public enum SpeechEngineError: Error, Equatable {
    case invalidConfiguration(String)
    case processFailure(String)
    case emptyTranscript
}

public protocol SpeechEngine {
    func transcribe(_ request: SpeechTranscriptionRequest) throws -> SpeechTranscriptionResult
}
```

```swift
// Sources/AleVoiceCore/SpeechEngineConfig.swift
import Foundation

public struct EnginePathConfig: Codable, Equatable {
    public let binaryPath: String
    public let modelPath: String
    public let defaultMode: SpeechLanguageMode
}

public struct SpeechEngineSettings: Codable, Equatable {
    public let engine: SpeechEngineKind
    public let funasr: EnginePathConfig

    public static func load(from url: URL) throws -> SpeechEngineSettings {
        let data = try Data(contentsOf: url)
        let settings = try JSONDecoder().decode(SpeechEngineSettings.self, from: data)
        guard !settings.funasr.binaryPath.isEmpty else {
            throw SpeechEngineError.invalidConfiguration("funasr binaryPath must be non-empty")
        }
        guard !settings.funasr.modelPath.isEmpty else {
            throw SpeechEngineError.invalidConfiguration("funasr modelPath must be non-empty")
        }
        return settings
    }
}
```

```json
{
  "engine": "funasr",
  "funasr": {
    "binaryPath": "/absolute/path/to/llama-funasr-sensevoice",
    "modelPath": "/absolute/path/to/sensevoice-small-f16.gguf",
    "defaultMode": "auto"
  }
}
```

```gitignore
# .gitignore
Config/speech-engine.json
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SpeechEngineConfigTests`
Expected: PASS with 2 tests passed.

- [ ] **Step 5: Commit**

```bash
git add .gitignore Package.swift Config/speech-engine.example.json Sources/AleVoiceCore/SpeechEngine.swift Sources/AleVoiceCore/SpeechEngineConfig.swift Tests/AleVoiceCoreTests/SpeechEngineConfigTests.swift
git commit -m "feat: scaffold native stt package and config"
```

### Task 2: Add Mockable Process Runner And FunASR Backend

**Files:**
- Create: `Sources/AleVoiceCore/ProcessRunning.swift`
- Create: `Sources/AleVoiceCore/FunASRSpeechEngine.swift`
- Test: `Tests/AleVoiceCoreTests/FunASRSpeechEngineTests.swift`

- [ ] **Step 1: Write failing FunASR engine tests**

```swift
import XCTest
@testable import AleVoiceCore

final class FunASRSpeechEngineTests: XCTestCase {
    func test_buildCommandMatchesBenchmarkShape() throws {
        let config = EnginePathConfig(
            binaryPath: "/tmp/funasr",
            modelPath: "/tmp/funasr.gguf",
            defaultMode: .auto
        )
        let engine = FunASRSpeechEngine(config: config, runner: FakeRunner())
        let request = SpeechTranscriptionRequest(audioURL: URL(fileURLWithPath: "/tmp/en-001.wav"), mode: .en)

        XCTAssertEqual(
            engine.buildCommand(for: request),
            ["/tmp/funasr", "-m", "/tmp/funasr.gguf", "-a", "/tmp/en-001.wav"]
        )
    }

    func test_transcribeStripsTimestampWrapperAndReturnsLatency() throws {
        let runner = FakeRunner(stdout: "[00:00:00.000 --> 00:00:02.000]   hello from engine\n")
        let config = EnginePathConfig(
            binaryPath: "/tmp/funasr",
            modelPath: "/tmp/funasr.gguf",
            defaultMode: .auto
        )
        let engine = FunASRSpeechEngine(config: config, runner: runner)

        let result = try engine.transcribe(
            SpeechTranscriptionRequest(audioURL: URL(fileURLWithPath: "/tmp/en-001.wav"), mode: .auto)
        )

        XCTAssertEqual(result.engine, .funasr)
        XCTAssertEqual(result.modelIdentifier, "/tmp/funasr.gguf")
        XCTAssertEqual(result.transcript, "hello from engine")
        XCTAssertEqual(result.latencyMs, 250)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter FunASRSpeechEngineTests`
Expected: FAIL with missing `FunASRSpeechEngine` or `FakeRunner`.

- [ ] **Step 3: Write process runner and FunASR backend**

```swift
// Sources/AleVoiceCore/ProcessRunning.swift
import Foundation

public struct ProcessOutput: Equatable {
    public let stdout: String
    public let stderr: String
    public let latencyMs: Int
}

public protocol ProcessRunning {
    func run(command: [String]) throws -> ProcessOutput
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(command: [String]) throws -> ProcessOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        let start = Date()
        try process.run()
        process.waitUntilExit()
        let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw SpeechEngineError.processFailure(stderr.isEmpty ? "funasr exited \(process.terminationStatus)" : stderr)
        }
        return ProcessOutput(stdout: stdout, stderr: stderr, latencyMs: latencyMs)
    }
}
```

```swift
// Sources/AleVoiceCore/FunASRSpeechEngine.swift
import Foundation

public final class FunASRSpeechEngine: SpeechEngine {
    private let config: EnginePathConfig
    private let runner: ProcessRunning

    public init(config: EnginePathConfig, runner: ProcessRunning = SystemProcessRunner()) {
        self.config = config
        self.runner = runner
    }

    public func buildCommand(for request: SpeechTranscriptionRequest) -> [String] {
        [
            config.binaryPath,
            "-m",
            config.modelPath,
            "-a",
            request.audioURL.path,
        ]
    }

    public func transcribe(_ request: SpeechTranscriptionRequest) throws -> SpeechTranscriptionResult {
        let output = try runner.run(command: buildCommand(for: request))
        let transcript = Self.parseTranscript(output.stdout)
        guard !transcript.isEmpty else {
            throw SpeechEngineError.emptyTranscript
        }
        return SpeechTranscriptionResult(
            engine: .funasr,
            modelIdentifier: config.modelPath,
            transcript: transcript,
            latencyMs: output.latencyMs
        )
    }

    static func parseTranscript(_ stdout: String) -> String {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let timestampPattern = #"^\[\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}\]\s*"#
        return trimmed.replacingOccurrences(
            of: timestampPattern,
            with: "",
            options: .regularExpression
        )
    }
}
```

```swift
// inside Tests/AleVoiceCoreTests/FunASRSpeechEngineTests.swift
private struct FakeRunner: ProcessRunning {
    var stdout: String = "hello from engine\n"
    var latencyMs: Int = 250

    func run(command: [String]) throws -> ProcessOutput {
        ProcessOutput(stdout: stdout, stderr: "", latencyMs: latencyMs)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter FunASRSpeechEngineTests`
Expected: PASS with 2 tests passed.

- [ ] **Step 5: Commit**

```bash
git add Sources/AleVoiceCore/ProcessRunning.swift Sources/AleVoiceCore/FunASRSpeechEngine.swift Tests/AleVoiceCoreTests/FunASRSpeechEngineTests.swift
git commit -m "feat: add funasr speech backend"
```

### Task 3: Add Coordinator And CLI Smoke Runner

**Files:**
- Modify: `Package.swift`
- Create: `Sources/AleVoiceCore/TranscriptionCoordinator.swift`
- Create: `Sources/AleVoiceCLI/main.swift`
- Test: `Tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift`

- [ ] **Step 1: Write failing coordinator tests**

```swift
import XCTest
@testable import AleVoiceCore

final class TranscriptionCoordinatorTests: XCTestCase {
    func test_makeEngineBuildsFunASRFromSettings() throws {
        let settings = SpeechEngineSettings(
            engine: .funasr,
            funasr: EnginePathConfig(
                binaryPath: "/tmp/funasr",
                modelPath: "/tmp/funasr.gguf",
                defaultMode: .vi
            )
        )

        let coordinator = TranscriptionCoordinator(settings: settings) { config in
            StubEngine(result: .init(engine: .funasr, modelIdentifier: config.modelPath, transcript: "xin chao", latencyMs: 111))
        }

        let result = try coordinator.transcribe(
            audioURL: URL(fileURLWithPath: "/tmp/vi-001.wav"),
            overrideMode: nil
        )

        XCTAssertEqual(result.transcript, "xin chao")
        XCTAssertEqual(result.latencyMs, 111)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TranscriptionCoordinatorTests`
Expected: FAIL with missing `TranscriptionCoordinator` or `StubEngine`.

- [ ] **Step 3: Write coordinator and CLI entrypoint**

```swift
// Package.swift additions
// Add executable product:
.executable(name: "AleVoiceCLI", targets: ["AleVoiceCLI"])

// Add executable target:
.executableTarget(name: "AleVoiceCLI", dependencies: ["AleVoiceCore"])
```

```swift
// Sources/AleVoiceCore/TranscriptionCoordinator.swift
import Foundation

public struct TranscriptionCoordinator {
    private let settings: SpeechEngineSettings
    private let engineFactory: (EnginePathConfig) -> SpeechEngine

    public init(
        settings: SpeechEngineSettings,
        engineFactory: @escaping (EnginePathConfig) -> SpeechEngine = { FunASRSpeechEngine(config: $0) }
    ) {
        self.settings = settings
        self.engineFactory = engineFactory
    }

    public func transcribe(audioURL: URL, overrideMode: SpeechLanguageMode?) throws -> SpeechTranscriptionResult {
        let engine = engineFactory(settings.funasr)
        let request = SpeechTranscriptionRequest(
            audioURL: audioURL,
            mode: overrideMode ?? settings.funasr.defaultMode
        )
        return try engine.transcribe(request)
    }
}
```

```swift
// Sources/AleVoiceCLI/main.swift
import AleVoiceCore
import Foundation

struct CLIError: Error, CustomStringConvertible {
    let description: String
}

@main
struct AleVoiceCLI {
    static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else {
            return nil
        }
        return args[index + 1]
    }

    static func main() throws {
        let args = CommandLine.arguments
        guard
            let configPath = value(after: "--config", in: args),
            let audioPath = value(after: "--audio", in: args)
        else {
            throw CLIError(description: "usage: AleVoiceCLI --config <path> --audio <path> [--mode auto|en|vi]")
        }
        let configURL = URL(fileURLWithPath: configPath)
        let audioURL = URL(fileURLWithPath: audioPath)
        let mode = value(after: "--mode", in: args).flatMap(SpeechLanguageMode.init(rawValue:))
        let settings = try SpeechEngineSettings.load(from: configURL)
        let coordinator = TranscriptionCoordinator(settings: settings)
        let result = try coordinator.transcribe(audioURL: audioURL, overrideMode: mode)
        print("engine=\(result.engine.rawValue)")
        print("latency_ms=\(result.latencyMs)")
        print(result.transcript)
    }
}
```

```swift
// inside Tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift
private struct StubEngine: SpeechEngine {
    let result: SpeechTranscriptionResult

    func transcribe(_ request: SpeechTranscriptionRequest) throws -> SpeechTranscriptionResult {
        result
    }
}
```

- [ ] **Step 4: Run tests and smoke CLI**

Run: `swift test --filter TranscriptionCoordinatorTests`
Expected: PASS with 1 test passed.

Run: `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
Expected: prints `engine=funasr`, `latency_ms=<number>`, then transcript text.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/AleVoiceCore/TranscriptionCoordinator.swift Sources/AleVoiceCLI/main.swift Tests/AleVoiceCoreTests/TranscriptionCoordinatorTests.swift
git commit -m "feat: add native transcription coordinator and cli"
```

### Task 4: Add Native Debug View Model And Minimal SwiftUI Shell

**Files:**
- Modify: `Package.swift`
- Create: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Create: `Sources/AleVoiceAppUI/ContentView.swift`
- Create: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Test: `Tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift`

- [ ] **Step 1: Write failing view model tests**

```swift
import XCTest
@testable import AleVoiceAppUI
import AleVoiceCore

final class TranscriptionDebugViewModelTests: XCTestCase {
    func test_runSampleUpdatesTranscriptAndLatency() async throws {
        let result = SpeechTranscriptionResult(
            engine: .funasr,
            modelIdentifier: "sensevoice-small",
            transcript: "hello world",
            latencyMs: 210
        )
        let viewModel = TranscriptionDebugViewModel(
            transcribe: { _, _, _ in result }
        )

        await viewModel.runSample(
            configURL: URL(fileURLWithPath: "/tmp/config.json"),
            audioURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            mode: .auto
        )

        XCTAssertEqual(viewModel.transcript, "hello world")
        XCTAssertEqual(viewModel.latencyText, "210 ms")
        XCTAssertNil(viewModel.errorText)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TranscriptionDebugViewModelTests`
Expected: FAIL with missing `TranscriptionDebugViewModel`.

- [ ] **Step 3: Write debug view model and app shell**

```swift
// Package.swift additions
// Add products:
.library(name: "AleVoiceAppUI", targets: ["AleVoiceAppUI"])
.executable(name: "AleVoiceApp", targets: ["AleVoiceApp"])

// Add targets:
.target(name: "AleVoiceAppUI", dependencies: ["AleVoiceCore"])
.executableTarget(name: "AleVoiceApp", dependencies: ["AleVoiceCore", "AleVoiceAppUI"])
.testTarget(name: "AleVoiceAppUITests", dependencies: ["AleVoiceAppUI", "AleVoiceCore"])
```

```swift
// Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift
import AleVoiceCore
import Combine
import Foundation

@MainActor
public final class TranscriptionDebugViewModel: ObservableObject {
    @Published var transcript: String = ""
    @Published var latencyText: String = ""
    @Published var errorText: String?

    private let transcribeClosure: (URL, URL, SpeechLanguageMode) throws -> SpeechTranscriptionResult

    public init(
        transcribe: @escaping (URL, URL, SpeechLanguageMode) throws -> SpeechTranscriptionResult
    ) {
        self.transcribeClosure = transcribe
    }

    public func runSample(configURL: URL, audioURL: URL, mode: SpeechLanguageMode) async {
        do {
            let result = try transcribeClosure(configURL, audioURL, mode)
            transcript = result.transcript
            latencyText = "\(result.latencyMs) ms"
            errorText = nil
        } catch {
            transcript = ""
            latencyText = ""
            errorText = String(describing: error)
        }
    }
}
```

```swift
// Sources/AleVoiceAppUI/ContentView.swift
import AleVoiceCore
import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel: TranscriptionDebugViewModel

    public init(viewModel: TranscriptionDebugViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Transcribe en-001 sample") {
                Task {
                    await viewModel.runSample(
                        configURL: URL(fileURLWithPath: "Config/speech-engine.json"),
                        audioURL: URL(fileURLWithPath: "data/benchmarks/samples/en-001.wav"),
                        mode: .auto
                    )
                }
            }
            Text(viewModel.latencyText)
            Text(viewModel.transcript).textSelection(.enabled)
            if let errorText = viewModel.errorText {
                Text(errorText).foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 220)
    }
}
```

```swift
// Sources/AleVoiceApp/AleVoiceApp.swift
import AleVoiceCore
import AleVoiceAppUI
import SwiftUI

@main
struct AleVoiceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: TranscriptionDebugViewModel(
                    transcribe: { configURL, audioURL, mode in
                        let settings = try SpeechEngineSettings.load(from: configURL)
                        let coordinator = TranscriptionCoordinator(settings: settings)
                        return try coordinator.transcribe(audioURL: audioURL, overrideMode: mode)
                    }
                )
            )
        }
    }
}
```

- [ ] **Step 4: Run tests and launch app shell**

Run: `swift test --filter TranscriptionDebugViewModelTests`
Expected: PASS with 1 test passed.

Run: `swift run AleVoiceApp`
Expected: app launches, button click runs sample transcription, transcript and latency appear in window.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/AleVoiceApp/AleVoiceApp.swift Sources/AleVoiceAppUI/ContentView.swift Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift Tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift
git commit -m "feat: add native debug shell for funasr transcription"
```

### Task 5: Record Proof And Close Planning Loop

**Files:**
- Create: `docs/validation/us-002-funasr-first-native-transcription-core.md`
- Modify: `docs/stories/epics/E01-local-stt/US-002-funasr-first-native-transcription-core.md`

- [ ] **Step 1: Write failing proof expectation into story evidence section**

```md
## Evidence

- pending: `swift test`
- pending: `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
- pending: native debug shell screenshot or log proving transcript and latency render
```

- [ ] **Step 2: Run verification commands and gather outputs**

Run: `cp Config/speech-engine.example.json Config/speech-engine.json`
Expected: local config file exists and stays untracked because `.gitignore` ignores it.

Edit `Config/speech-engine.json` so paths match current local FunASR runtime:

```json
{
  "engine": "funasr",
  "funasr": {
    "binaryPath": "/Users/alex/workspace/Projects/alevoice/tmp/funasr-runtime/llama-funasr-sensevoice",
    "modelPath": "/Users/alex/workspace/Projects/alevoice/tmp/stt-models/funasr-sensevoice/sensevoice-small-f16.gguf",
    "defaultMode": "auto"
  }
}
```

Run: `swift test`
Expected: PASS for `AleVoiceCoreTests` and `AleVoiceAppUITests`.

Run: `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
Expected: transcript text plus `engine=funasr` and `latency_ms=<number>`.

Run: `swift run AleVoiceApp`
Expected: app launches and displays same sample transcript through native UI.

- [ ] **Step 3: Write validation report and update story evidence**

```md
<!-- docs/validation/us-002-funasr-first-native-transcription-core.md -->
# US-002 Validation Report

## Summary

FunASR-backed native transcription core works through shared Swift boundary.

## Commands

- `swift test`
- `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
- `swift run AleVoiceApp`

## Evidence

- CLI output prints `engine=funasr`, latency, and transcript.
- Native debug shell displays transcript and latency for `en-001`.
- Config remains centralized in `Config/speech-engine.json`.

## Known Limits

- No microphone capture yet.
- No global hotkey or paste automation yet.
- `whisper.cpp` backend not added in app code yet; switch path remains architectural only.
```

```md
<!-- append to docs/stories/epics/E01-local-stt/US-002-funasr-first-native-transcription-core.md -->
## Evidence

- `swift test`
- `swift run AleVoiceCLI --config Config/speech-engine.json --audio data/benchmarks/samples/en-001.wav --mode auto`
- `swift run AleVoiceApp`
- `docs/validation/us-002-funasr-first-native-transcription-core.md`
```

- [ ] **Step 4: Update Harness durable row**

Run: `scripts/bin/harness-cli story update --id US-002 --status implemented --unit 1 --integration 1 --e2e 0 --platform 1`
Expected: story row reflects implemented status and proof flags.

- [ ] **Step 5: Commit**

```bash
git add docs/validation/us-002-funasr-first-native-transcription-core.md docs/stories/epics/E01-local-stt/US-002-funasr-first-native-transcription-core.md
git commit -m "docs: record funasr native transcription proof"
```

## Self-Review

- Spec coverage: plan covers FunASR-first default, pluggable engine contract, centralized config, CLI smoke validation, native debug UI, and explicit proof artifacts for later `whisper.cpp` switch decisions.
- Placeholder scan: no `TBD`, `TODO`, or unnamed test/code steps remain.
- Type consistency: `SpeechEngineKind`, `SpeechLanguageMode`, `SpeechTranscriptionRequest`, `SpeechTranscriptionResult`, and `SpeechEngineSettings` stay consistent across config, engine, coordinator, CLI, and UI tasks.
