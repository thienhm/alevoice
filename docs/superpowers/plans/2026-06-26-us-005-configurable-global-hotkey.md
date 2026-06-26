# US-005 Configurable Global Hotkey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add user-configurable global hold-to-record shortcut with Input Monitoring visibility, persisted shortcut selection, and release-to-transcribe lifecycle in native debug app.

**Architecture:** Keep shortcut modeling and hold-state logic in `AleVoiceCore` as pure Swift types with tests. Keep Quartz event tap and Input Monitoring adapters in `AleVoiceApp`, then extend `TranscriptionDebugViewModel` and `ContentView` so shortcut capture, status text, and hotkey-driven recording reuse existing recorder/transcriber flow.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, Foundation, CoreGraphics Quartz Event Services, UserDefaults, XCTest

---

## File Map

- Create: `docs/product/local-dictation-workflow.md`
- Create: `docs/stories/epics/E01-local-stt/US-005-configurable-global-hotkey-and-input-monitoring.md`
- Create: `docs/validation/us-005-configurable-global-hotkey-and-input-monitoring.md`
- Create: `docs/superpowers/plans/2026-06-26-us-005-configurable-global-hotkey.md`
- Create: `Sources/AleVoiceCore/DictationShortcut.swift`
- Create: `Sources/AleVoiceCore/DictationShortcutStore.swift`
- Create: `Sources/AleVoiceCore/GlobalHotkeyStateMachine.swift`
- Create: `Sources/AleVoiceCore/InputMonitoringPermission.swift`
- Create: `Sources/AleVoiceApp/QuartzInputMonitoringPermission.swift`
- Create: `Sources/AleVoiceApp/QuartzHotkeyServices.swift`
- Create: `tests/AleVoiceCoreTests/DictationShortcutTests.swift`
- Create: `tests/AleVoiceCoreTests/DictationShortcutStoreTests.swift`
- Create: `tests/AleVoiceCoreTests/GlobalHotkeyStateMachineTests.swift`
- Create: `tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Modify: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`

### Task 1: Product Doc And Story Scaffolding

**Files:**
- Create: `docs/product/local-dictation-workflow.md`
- Create: `docs/stories/epics/E01-local-stt/US-005-configurable-global-hotkey-and-input-monitoring.md`
- Create: `docs/validation/us-005-configurable-global-hotkey-and-input-monitoring.md`

- [ ] **Step 1: Write product doc for local dictation workflow**

```md
# Local Dictation Workflow

## Goal

Define current native macOS dictation workflow after benchmark phase.

## Current Workflow Contract

- User launches native debug app locally.
- User can inspect microphone and Input Monitoring status in app UI.
- User can choose language mode for transcription.
- User can record a dictation shortcut in UI.
- App persists chosen shortcut locally.
- Holding configured shortcut starts microphone capture.
- Releasing configured shortcut stops capture and transcribes through current
  FunASR-first path.

## Out Of Scope

- Paste transcript into focused app
- Overlay UI
- Formatting-command normalization
- Conflict resolution beyond rejecting unsupported or modifier-free shortcuts
```

- [ ] **Step 2: Write story packet**

```md
# US-005 Configurable Global Hotkey And Input Monitoring

## Status

planned

## Lane

normal

## Product Contract

Native macOS debug shell lets user record a persisted dictation shortcut, shows
Input Monitoring status, and uses shortcut hold/release lifecycle to drive the
existing microphone recording and transcription path.

## Relevant Product Docs

- `docs/product/local-dictation-workflow.md`
- `docs/product/stt-engine-benchmarking.md`
- `docs/superpowers/specs/2026-06-26-configurable-global-hotkey-design.md`
- `docs/stories/epics/E01-local-stt/US-004-reliable-native-app-shell-and-permissions.md`

## Acceptance Criteria

- User can record shortcut in UI and see human-readable persisted value.
- Shortcut must include at least one modifier.
- Input Monitoring state is visible and refreshable in UI.
- Global shortcut activation starts recording once.
- Shortcut release stops recording and transcribes once.
- Existing manual recorder controls still work.
- No paste, overlay, or formatting behavior is added in this slice.

## Design Notes

- Commands: record shortcut, refresh/request Input Monitoring, start recording,
  stop recording and transcribe.
- Queries: current shortcut, capture-mode state, Input Monitoring state,
  recording state, latest transcript, latest latency, latest error.
- API: no network API.
- Tables: no app database tables.
- Domain rules:
  - shortcut requires at least one modifier
  - bare character keys are rejected
  - release of any required key ends recording
  - capture mode must suppress live dictation trigger
- UI surfaces:
  - native SwiftUI debug shell
  - shortcut capture row
  - Input Monitoring row

## Validation

When updating durable proof status, use numeric booleans:
`scripts/bin/harness-cli story update --id US-005 --unit 1 --integration 1 --e2e 0 --platform 1`.

| Layer | Expected proof |
| --- | --- |
| Unit | Shortcut modeling, persistence, and state-machine tests pass. |
| Integration | Debug view model applies captured shortcut and routes release to existing transcription path. |
| E2E | Not required for this slice; no paste automation or overlay yet. |
| Platform | Configured shortcut starts and stops recording globally on target Mac after Input Monitoring approval. |
| Release | Validation report records commands, platform proof, and known shortcut limitations. |

## Harness Delta

- Add first product doc for non-benchmark dictation workflow.
- Add story packet and validation note for configurable shortcut slice.

## Evidence

Add commands, screenshots, and manual proof after implementation.
```

- [ ] **Step 3: Register durable story row**

Run:

```bash
rtk scripts/bin/harness-cli story add --id US-005 --title "Configurable global hotkey and Input Monitoring hold lifecycle" --lane normal --verify "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test"
```

Expected: story row created for `US-005`.

- [ ] **Step 4: Commit scaffolding**

```bash
rtk git add docs/product/local-dictation-workflow.md docs/stories/epics/E01-local-stt/US-005-configurable-global-hotkey-and-input-monitoring.md docs/validation/us-005-configurable-global-hotkey-and-input-monitoring.md
rtk git commit -m "Add US-005 story scaffolding"
```

### Task 2: Shortcut Model And Persistence

**Files:**
- Create: `tests/AleVoiceCoreTests/DictationShortcutTests.swift`
- Create: `tests/AleVoiceCoreTests/DictationShortcutStoreTests.swift`
- Create: `Sources/AleVoiceCore/DictationShortcut.swift`
- Create: `Sources/AleVoiceCore/DictationShortcutStore.swift`

- [ ] **Step 1: Write failing shortcut model tests**

```swift
import XCTest
@testable import AleVoiceCore

final class DictationShortcutTests: XCTestCase {
    func test_initRejectsShortcutWithoutModifier() throws {
        XCTAssertThrowsError(
            try DictationShortcut(modifiers: [], primaryKey: .space)
        ) { error in
            XCTAssertEqual(error as? DictationShortcutError, .missingModifier)
        }
    }

    func test_initAcceptsModifierOnlyShortcut() throws {
        let shortcut = try DictationShortcut(modifiers: [.control], primaryKey: nil)

        XCTAssertEqual(shortcut.displayText, "Control")
    }

    func test_initAcceptsModifierAndPrimaryKeyShortcut() throws {
        let shortcut = try DictationShortcut(modifiers: [.control, .shift], primaryKey: .space)

        XCTAssertEqual(shortcut.displayText, "Control+Shift+Space")
    }

    func test_supportedPrimaryKeyRejectsUnknownCodes() {
        XCTAssertNil(DictationShortcut.PrimaryKey(keyCode: 255))
    }
}
```

```swift
import XCTest
@testable import AleVoiceCore

final class DictationShortcutStoreTests: XCTestCase {
    func test_saveThenLoadRoundTripsShortcut() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = UserDefaultsDictationShortcutStore(userDefaults: defaults)
        let shortcut = try DictationShortcut(modifiers: [.command], primaryKey: .keyD)

        try store.save(shortcut)

        XCTAssertEqual(store.load(), shortcut)
    }

    func test_loadReturnsNilForCorruptPayload() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(Data("bad".utf8), forKey: "dictationShortcut")
        let store = UserDefaultsDictationShortcutStore(userDefaults: defaults)

        XCTAssertNil(store.load())
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter DictationShortcutTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter DictationShortcutStoreTests
```

Expected: FAIL because shortcut types and store do not exist yet.

- [ ] **Step 3: Write minimal shortcut model and store**

```swift
// Sources/AleVoiceCore/DictationShortcut.swift
import Foundation

public enum DictationShortcutError: Error, Equatable, LocalizedError, Sendable {
    case missingModifier
    case unsupportedPrimaryKey(UInt16)

    public var errorDescription: String? {
        switch self {
        case .missingModifier:
            return "Shortcut must include at least one modifier"
        case .unsupportedPrimaryKey(let keyCode):
            return "Shortcut key code \(keyCode) is not supported"
        }
    }
}

public struct DictationShortcut: Codable, Equatable, Sendable {
    public struct ModifierSet: OptionSet, Codable, Equatable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let command = ModifierSet(rawValue: 1 << 0)
        public static let shift = ModifierSet(rawValue: 1 << 1)
        public static let option = ModifierSet(rawValue: 1 << 2)
        public static let control = ModifierSet(rawValue: 1 << 3)
        public static let function = ModifierSet(rawValue: 1 << 4)
    }

    public struct PrimaryKey: Codable, Equatable, Sendable {
        public let keyCode: UInt16
        public let displayName: String

        public init?(keyCode: UInt16) {
            guard let displayName = Self.supportedKeys[keyCode] else {
                return nil
            }
            self.keyCode = keyCode
            self.displayName = displayName
        }

        public static let space = PrimaryKey(keyCode: 49)!
        public static let keyD = PrimaryKey(keyCode: 2)!

        private static let supportedKeys: [UInt16: String] = [
            49: "Space",
            0: "A",
            1: "S",
            2: "D",
            13: "W"
        ]
    }

    public let modifiers: ModifierSet
    public let primaryKey: PrimaryKey?

    public init(modifiers: ModifierSet, primaryKey: PrimaryKey?) throws {
        guard !modifiers.isEmpty else {
            throw DictationShortcutError.missingModifier
        }
        self.modifiers = modifiers
        self.primaryKey = primaryKey
    }

    public var displayText: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Command") }
        if modifiers.contains(.function) { parts.append("Fn") }
        if let primaryKey {
            parts.append(primaryKey.displayName)
        }
        return parts.joined(separator: "+")
    }
}
```

```swift
// Sources/AleVoiceCore/DictationShortcutStore.swift
import Foundation

public protocol DictationShortcutStore: Sendable {
    func load() -> DictationShortcut?
    func save(_ shortcut: DictationShortcut?) throws
}

public struct UserDefaultsDictationShortcutStore: DictationShortcutStore {
    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "dictationShortcut"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    public func load() -> DictationShortcut? {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DictationShortcut.self, from: data)
    }

    public func save(_ shortcut: DictationShortcut?) throws {
        guard let shortcut else {
            userDefaults.removeObject(forKey: storageKey)
            return
        }
        let data = try JSONEncoder().encode(shortcut)
        userDefaults.set(data, forKey: storageKey)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter DictationShortcutTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter DictationShortcutStoreTests
```

Expected: PASS for both test files.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/AleVoiceCoreTests/DictationShortcutTests.swift tests/AleVoiceCoreTests/DictationShortcutStoreTests.swift Sources/AleVoiceCore/DictationShortcut.swift Sources/AleVoiceCore/DictationShortcutStore.swift
rtk git commit -m "Add configurable shortcut model and store"
```

### Task 3: Pure Hold-State Machine

**Files:**
- Create: `tests/AleVoiceCoreTests/GlobalHotkeyStateMachineTests.swift`
- Create: `Sources/AleVoiceCore/GlobalHotkeyStateMachine.swift`

- [ ] **Step 1: Write failing state-machine tests**

```swift
import XCTest
@testable import AleVoiceCore

final class GlobalHotkeyStateMachineTests: XCTestCase {
    func test_modifierAndPrimaryKeyActivateOnce() throws {
        let shortcut = try DictationShortcut(modifiers: [.control], primaryKey: .space)
        var machine = GlobalHotkeyStateMachine(shortcut: shortcut)

        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.control])),
            []
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyDown, keyCode: 49, modifiers: [.control])),
            [.activated]
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyDown, keyCode: 49, modifiers: [.control])),
            []
        )
    }

    func test_releaseAnyRequiredInputEmitsReleasedOnce() throws {
        let shortcut = try DictationShortcut(modifiers: [.control, .shift], primaryKey: .space)
        var machine = GlobalHotkeyStateMachine(shortcut: shortcut)

        _ = machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.control, .shift]))
        _ = machine.handle(GlobalKeyEvent(kind: .keyDown, keyCode: 49, modifiers: [.control, .shift]))

        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.control])),
            [.released]
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .keyUp, keyCode: 49, modifiers: [.control])),
            []
        )
    }

    func test_modifierOnlyShortcutUsesFlagsChangedLifecycle() throws {
        let shortcut = try DictationShortcut(modifiers: [.option], primaryKey: nil)
        var machine = GlobalHotkeyStateMachine(shortcut: shortcut)

        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [.option])),
            [.activated]
        )
        XCTAssertEqual(
            machine.handle(GlobalKeyEvent(kind: .flagsChanged, keyCode: nil, modifiers: [])),
            [.released]
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter GlobalHotkeyStateMachineTests
```

Expected: FAIL because event and state-machine types do not exist yet.

- [ ] **Step 3: Write minimal state machine**

```swift
import Foundation

public struct GlobalKeyEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case keyDown
        case keyUp
        case flagsChanged
    }

    public let kind: Kind
    public let keyCode: UInt16?
    public let modifiers: DictationShortcut.ModifierSet

    public init(kind: Kind, keyCode: UInt16?, modifiers: DictationShortcut.ModifierSet) {
        self.kind = kind
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum GlobalHotkeyTransition: Equatable, Sendable {
    case activated
    case released
}

public struct GlobalHotkeyStateMachine: Sendable {
    private let shortcut: DictationShortcut
    private var pressedPrimaryKeyCode: UInt16?
    private var wasActive = false

    public init(shortcut: DictationShortcut) {
        self.shortcut = shortcut
    }

    public mutating func handle(_ event: GlobalKeyEvent) -> [GlobalHotkeyTransition] {
        switch event.kind {
        case .keyDown:
            pressedPrimaryKeyCode = event.keyCode
        case .keyUp:
            if pressedPrimaryKeyCode == event.keyCode {
                pressedPrimaryKeyCode = nil
            }
        case .flagsChanged:
            break
        }

        let modifiersMatch = event.modifiers.isSuperset(of: shortcut.modifiers)
        let primaryMatches = shortcut.primaryKey.map { $0.keyCode == pressedPrimaryKeyCode } ?? true
        let isActive = modifiersMatch && primaryMatches

        defer { wasActive = isActive }

        if isActive && !wasActive {
            return [.activated]
        }
        if !isActive && wasActive {
            return [.released]
        }
        return []
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter GlobalHotkeyStateMachineTests
```

Expected: PASS for activation and release lifecycle coverage.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/AleVoiceCoreTests/GlobalHotkeyStateMachineTests.swift Sources/AleVoiceCore/GlobalHotkeyStateMachine.swift
rtk git commit -m "Add global hotkey state machine"
```

### Task 4: View Model And UI State

**Files:**
- Create: `tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift`
- Create: `Sources/AleVoiceCore/InputMonitoringPermission.swift`
- Modify: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`

- [ ] **Step 1: Write failing UI/view-model tests**

```swift
import XCTest
@testable import AleVoiceAppUI
import AleVoiceCore

final class GlobalHotkeyDebugViewModelTests: XCTestCase {
    @MainActor
    func test_refreshInputMonitoringStatusShowsAuthorizedState() async {
        let viewModel = TranscriptionDebugViewModel(
            inputMonitoringPermissionStatus: { .authorized },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.refreshInputMonitoringStatus()

        XCTAssertEqual(viewModel.inputMonitoringStatusText, "Input Monitoring: authorized")
    }

    @MainActor
    func test_captureShortcutSavesDisplayTextAndClearsError() async {
        let shortcut = try! DictationShortcut(modifiers: [.control], primaryKey: .space)
        let viewModel = TranscriptionDebugViewModel(
            beginShortcutCapture: { .success(shortcut) },
            saveShortcut: { saved in
                XCTAssertEqual(saved, shortcut)
            },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.captureShortcut()

        XCTAssertEqual(viewModel.shortcutDisplayText, "Dictation shortcut: Control+Space")
        XCTAssertNil(viewModel.errorText)
        XCTAssertFalse(viewModel.isCapturingShortcut)
    }

    @MainActor
    func test_captureShortcutRejectsMissingModifier() async {
        let viewModel = TranscriptionDebugViewModel(
            beginShortcutCapture: { .failure(.missingModifier) },
            transcribe: { _, _, _ in fatalError() }
        )

        await viewModel.captureShortcut()

        XCTAssertEqual(viewModel.errorText, "Shortcut must include at least one modifier")
        XCTAssertEqual(viewModel.shortcutDisplayText, "Dictation shortcut: not set")
    }

    @MainActor
    func test_hotkeyReleaseUsesSelectedMode() async throws {
        let probe = TranscriptionProbe()
        let shortcut = try! DictationShortcut(modifiers: [.control], primaryKey: .space)
        let viewModel = TranscriptionDebugViewModel(
            loadShortcut: { shortcut },
            startRecording: {},
            stopRecording: {
                AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 123)
            },
            transcribe: { configURL, audioURL, mode in
                await probe.record(configURL: configURL, audioURL: audioURL, mode: mode)
                return SpeechTranscriptionResult(
                    engine: .funasr,
                    modelIdentifier: "sensevoice-small",
                    transcript: "hello",
                    latencyMs: 99
                )
            }
        )
        viewModel.selectedMode = .vi
        await viewModel.startRecording()
        await viewModel.handleGlobalShortcutRelease(configURL: URL(fileURLWithPath: "/tmp/config.json"))

        let invocation = await probe.invocation()
        XCTAssertEqual(invocation?.mode, .vi)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter GlobalHotkeyDebugViewModelTests
```

Expected: FAIL because hotkey-related view-model API does not exist yet.

- [ ] **Step 3: Add permission type, view-model state, and content view bindings**

```swift
// Sources/AleVoiceCore/InputMonitoringPermission.swift
import Foundation

public enum InputMonitoringPermissionStatus: Equatable, Sendable {
    case authorized
    case denied
    case notDetermined
    case unknown
}
```

```swift
// Key additions inside Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift
@Published public var selectedMode: SpeechLanguageMode = .auto
@Published public private(set) var inputMonitoringStatusText: String = "Input Monitoring: unknown"
@Published public private(set) var shortcutDisplayText: String = "Dictation shortcut: not set"
@Published public private(set) var shortcutCaptureText: String = ""
@Published public private(set) var isCapturingShortcut: Bool = false

private let inputMonitoringPermissionStatusClosure: @Sendable () async -> InputMonitoringPermissionStatus
private let requestInputMonitoringAccessClosure: @Sendable () async -> InputMonitoringPermissionStatus
private let loadShortcutClosure: @Sendable () -> DictationShortcut?
private let saveShortcutClosure: @Sendable (DictationShortcut?) throws -> Void
private let beginShortcutCaptureClosure: @Sendable () async -> Result<DictationShortcut, DictationShortcutError>
private let onShortcutChangeClosure: @Sendable (DictationShortcut?) -> Void

public func refreshInputMonitoringStatus() async {
    inputMonitoringStatusText = "Input Monitoring: \(displayText(for: await inputMonitoringPermissionStatusClosure()))"
}

public func loadShortcut() {
    let shortcut = loadShortcutClosure()
    shortcutDisplayText = "Dictation shortcut: \(shortcut?.displayText ?? "not set")"
    onShortcutChangeClosure(shortcut)
}

public func captureShortcut() async {
    isCapturingShortcut = true
    shortcutCaptureText = "Press shortcut..."
    let result = await beginShortcutCaptureClosure()
    isCapturingShortcut = false
    shortcutCaptureText = ""

    switch result {
    case .success(let shortcut):
        try? saveShortcutClosure(shortcut)
        shortcutDisplayText = "Dictation shortcut: \(shortcut.displayText)"
        onShortcutChangeClosure(shortcut)
        errorText = nil
    case .failure(let error):
        errorText = error.errorDescription
    }
}

public func handleGlobalShortcutActivation() async {
    await startRecording()
}

public func handleGlobalShortcutRelease(configURL: URL) async {
    await stopRecordingAndTranscribe(configURL: configURL, mode: selectedMode)
}
```

```swift
// Key additions inside Sources/AleVoiceAppUI/ContentView.swift
Text(viewModel.inputMonitoringStatusText)
Button("Refresh Input Monitoring") {
    Task { await viewModel.refreshInputMonitoringStatus() }
}

Text(viewModel.shortcutDisplayText)
Button("Record shortcut") {
    Task { await viewModel.captureShortcut() }
}
if !viewModel.shortcutCaptureText.isEmpty {
    Text(viewModel.shortcutCaptureText)
}

Picker("Language mode", selection: $viewModel.selectedMode) {
    Text("Auto").tag(SpeechLanguageMode.auto)
    Text("English").tag(SpeechLanguageMode.en)
    Text("Vietnamese").tag(SpeechLanguageMode.vi)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter GlobalHotkeyDebugViewModelTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionDebugViewModelTests
```

Expected: PASS for new and existing AppUI tests.

- [ ] **Step 5: Commit**

```bash
rtk git add tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift Sources/AleVoiceCore/InputMonitoringPermission.swift Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift Sources/AleVoiceAppUI/ContentView.swift
rtk git commit -m "Add hotkey state to debug view model"
```

### Task 5: Quartz Monitor, Capture Session, And App Wiring

**Files:**
- Create: `Sources/AleVoiceApp/QuartzInputMonitoringPermission.swift`
- Create: `Sources/AleVoiceApp/QuartzHotkeyServices.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`

- [ ] **Step 1: Add app-side adapters**

```swift
// Sources/AleVoiceApp/QuartzInputMonitoringPermission.swift
import AleVoiceCore
import CoreGraphics
import Foundation

struct QuartzInputMonitoringPermission {
    func status() -> InputMonitoringPermissionStatus {
        if CGPreflightListenEventAccess() {
            return .authorized
        }
        return .notDetermined
    }

    func requestAccess() -> InputMonitoringPermissionStatus {
        if CGRequestListenEventAccess() {
            return .authorized
        }
        return status() == .authorized ? .authorized : .denied
    }
}
```

```swift
// Sources/AleVoiceApp/QuartzHotkeyServices.swift
import AleVoiceCore
import AppKit
import CoreGraphics
import Foundation

@MainActor
final class QuartzHotkeyMonitor {
    private var shortcut: DictationShortcut?
    private var stateMachine: GlobalHotkeyStateMachine?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onTransition: (@Sendable (GlobalHotkeyTransition) -> Void)?

    init() {}

    func updateShortcut(_ shortcut: DictationShortcut?) {
        self.shortcut = shortcut
        self.stateMachine = shortcut.map(GlobalHotkeyStateMachine.init)
    }

    func start() {
        guard eventTap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<QuartzHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func handle(type: CGEventType, event: CGEvent) {
        guard var stateMachine else { return }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = DictationShortcut.ModifierSet(cgFlags: event.flags)
        let transitions = stateMachine.handle(GlobalKeyEvent(kind: type.hotkeyKind, keyCode: keyCode, modifiers: modifiers))
        self.stateMachine = stateMachine
        transitions.forEach { transition in
            onTransition?(transition)
        }
    }
}

@MainActor
final class QuartzShortcutCaptureController {
    func captureShortcut() async -> Result<DictationShortcut, DictationShortcutError> {
        await withCheckedContinuation { continuation in
            var localMonitor: Any?
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
                let modifiers = DictationShortcut.ModifierSet(nsFlags: event.modifierFlags)
                let primaryKey = DictationShortcut.PrimaryKey(keyCode: event.keyCode)
                guard !modifiers.isEmpty else {
                    continuation.resume(returning: .failure(.missingModifier))
                    if let localMonitor { NSEvent.removeMonitor(localMonitor) }
                    return nil
                }
                do {
                    let shortcut = try DictationShortcut(modifiers: modifiers, primaryKey: primaryKey)
                    continuation.resume(returning: .success(shortcut))
                } catch let error as DictationShortcutError {
                    continuation.resume(returning: .failure(error))
                } catch {
                    continuation.resume(returning: .failure(.missingModifier))
                }
                if let localMonitor { NSEvent.removeMonitor(localMonitor) }
                return nil
            }
        }
    }
}
```

- [ ] **Step 2: Wire app entrypoint**

```swift
import AleVoiceAppUI
import AleVoiceCore
import AppKit
import SwiftUI

@main
struct AleVoiceApp: App {
    @StateObject private var viewModel: TranscriptionDebugViewModel
    private let hotkeyMonitor: QuartzHotkeyMonitor

    init() {
        let audioRecorder = AudioRecorder()
        let shortcutStore = UserDefaultsDictationShortcutStore()
        let inputMonitoringPermission = QuartzInputMonitoringPermission()
        let shortcutCaptureController = QuartzShortcutCaptureController()
        let assetLocator = DebugAssetLocator()
        let configURL = assetLocator.speechEngineConfigURL()
        let monitor = QuartzHotkeyMonitor()
        let viewModel = TranscriptionDebugViewModel(
            inputMonitoringPermissionStatus: { inputMonitoringPermission.status() },
            requestInputMonitoringAccess: { inputMonitoringPermission.requestAccess() },
            loadShortcut: { shortcutStore.load() },
            saveShortcut: { try shortcutStore.save($0) },
            beginShortcutCapture: { await shortcutCaptureController.captureShortcut() },
            onShortcutChange: { monitor.updateShortcut($0) },
            microphonePermissionStatus: { await audioRecorder.microphonePermissionStatus() },
            startRecording: { try await audioRecorder.start() },
            stopRecording: { try await audioRecorder.stop() },
            transcribe: { configURL, audioURL, mode in
                try await Task.detached {
                    let settings = try SpeechEngineSettings.load(from: configURL)
                    let coordinator = TranscriptionCoordinator(settings: settings)
                    return try coordinator.transcribe(audioURL: audioURL, overrideMode: mode)
                }.value
            }
        )
        _viewModel = StateObject(
            wrappedValue: viewModel
        )
        self.hotkeyMonitor = monitor
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.hotkeyMonitor.start()
        self.hotkeyMonitor.updateShortcut(shortcutStore.load())
        self.hotkeyMonitor.onTransition = { transition in
            Task { @MainActor in
                switch transition {
                case .activated:
                    await viewModel.handleGlobalShortcutActivation()
                case .released:
                    await viewModel.handleGlobalShortcutRelease(configURL: configURL)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Run focused tests and app smoke**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app
```

Expected:
- `swift test` PASS
- app launches with new Input Monitoring row and shortcut capture button

- [ ] **Step 4: Manual platform verification**

Run and verify:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk ./scripts/run-alevoice-app
```

Manual checks:
- click `Record shortcut`
- press `Control+Space` or another supported combo
- confirm `Dictation shortcut: ...` text updates
- refresh/request Input Monitoring if needed
- hold configured shortcut outside focused text field
- verify UI changes to `Recording in progress`
- release shortcut
- verify transcript and latency render in app

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/AleVoiceApp/QuartzInputMonitoringPermission.swift Sources/AleVoiceApp/QuartzHotkeyServices.swift Sources/AleVoiceApp/AleVoiceApp.swift
rtk git commit -m "Wire Quartz hotkey monitoring into app"
```

### Task 6: Validation Report And Durable Proof

**Files:**
- Modify: `docs/stories/epics/E01-local-stt/US-005-configurable-global-hotkey-and-input-monitoring.md`
- Modify: `docs/validation/us-005-configurable-global-hotkey-and-input-monitoring.md`

- [ ] **Step 1: Write validation report**

```md
# US-005 Validation Report

## Summary

Configurable global dictation shortcut, Input Monitoring state, and hold-to-record
lifecycle are validated separately from future paste and overlay work.

## Commands Run

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/run-alevoice-app`

## Results

- Swift test suite passed.
- App launched with microphone status, Input Monitoring status, and shortcut capture UI.
- Recorded shortcut persisted across relaunch.
- Holding configured shortcut started recording exactly once.
- Releasing configured shortcut stopped recording and transcribed through FunASR path.

## Platform Proof

- Input Monitoring row showed current state.
- Shortcut row updated to captured shortcut text.
- Recording state changed to `Recording in progress` while shortcut held.
- Release changed state to `Last recording ready` and rendered transcript plus latency.

## Known Limits

- Some system-reserved combos may be unavailable or intercepted by macOS.
- This slice does not paste transcript, show overlay, or normalize formatting commands.
```

- [ ] **Step 2: Update story evidence and proof booleans**

Run:

```bash
rtk scripts/bin/harness-cli story update --id US-005 --status implemented --unit 1 --integration 1 --e2e 0 --platform 1 --evidence "2026-06-26: swift test passed; AleVoiceApp captured persisted shortcut, showed Input Monitoring state, and hotkey release transcribed live recording; see docs/validation/us-005-configurable-global-hotkey-and-input-monitoring.md"
```

Expected: `US-005` matrix row updated to implemented with proof flags.

- [ ] **Step 3: Run full matrix check**

Run:

```bash
rtk scripts/bin/harness-cli query matrix
rtk git status --short
```

Expected: `US-005` appears as implemented; working tree contains only intended files before final commit.

- [ ] **Step 4: Commit validation artifacts**

```bash
rtk git add docs/stories/epics/E01-local-stt/US-005-configurable-global-hotkey-and-input-monitoring.md docs/validation/us-005-configurable-global-hotkey-and-input-monitoring.md
rtk git commit -m "Document US-005 validation proof"
```

## Self-Review

- Spec coverage:
  - configurable captured shortcut: Task 2, Task 4, Task 5
  - Input Monitoring state: Task 4, Task 5
  - persisted shortcut: Task 2, Task 5
  - hold-to-record and release-to-transcribe lifecycle: Task 3, Task 4, Task 5
  - no paste/overlay/formatting: explicitly constrained in Task 1 docs and Task 6 validation
- Placeholder scan:
  - no `TODO`, `TBD`, or implicit “handle later” instructions remain
- Type consistency:
  - `DictationShortcut`, `DictationShortcutError`, `GlobalKeyEvent`, `GlobalHotkeyStateMachine`, and `InputMonitoringPermissionStatus` are named consistently across tasks

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-26-us-005-configurable-global-hotkey.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
