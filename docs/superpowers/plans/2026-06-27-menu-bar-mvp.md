# Menu Bar MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship AleVoice as a resident menu bar MVP with Auto-only dictation, overlay feedback, formatting normalization before paste, completed focused-app paste proof, and aligned product documentation.

**Architecture:** Keep the current recording and transcription core intact, promote `TranscriptionDebugViewModel` into the shared app-state coordinator, add a pure formatter plus small menu-bar and overlay AppKit adapters, and reduce the primary workflow to Auto-only to match current FunASR reality.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, Harness CLI, local FunASR path

---

## File Structure

- Create: `docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/overview.md`
- Create: `docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/design.md`
- Create: `docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/execplan.md`
- Create: `docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/validation.md`
- Create: `docs/superpowers/plans/2026-06-27-menu-bar-mvp.md`
- Create: `Sources/AleVoiceCore/DictationSessionState.swift`
- Create: `Sources/AleVoiceCore/TranscriptFormatter.swift`
- Create: `Sources/AleVoiceApp/MenuBarController.swift`
- Create: `Sources/AleVoiceApp/OverlayWindowController.swift`
- Create: `Sources/AleVoiceApp/OverlayView.swift`
- Create: `tests/AleVoiceCoreTests/TranscriptFormatterTests.swift`
- Create: `tests/AleVoiceAppTests/MenuBarControllerTests.swift`
- Create: `tests/AleVoiceAppTests/OverlayWindowControllerTests.swift`
- Modify: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Modify: `tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift`
- Modify: `tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift`
- Modify: `docs/product/local-dictation-workflow.md`
- Modify: `docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md`
- Modify: `docs/validation/us-006-paste-transcript-into-focused-app.md`
- Modify: `README.md`

### Task 1: Add transcript formatting rules in core

**Files:**
- Create: `Sources/AleVoiceCore/DictationSessionState.swift`
- Create: `tests/AleVoiceCoreTests/TranscriptFormatterTests.swift`
- Create: `Sources/AleVoiceCore/TranscriptFormatter.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AleVoiceCore

final class TranscriptFormatterTests: XCTestCase {
    func test_formats_english_newline_and_punctuation_commands() {
        let formatter = TranscriptFormatter()

        let output = formatter.format("new line benchmark summary colon faster period")

        XCTAssertEqual(output, "\nbenchmark summary: faster.")
    }

    func test_formats_vietnamese_commands() {
        let formatter = TranscriptFormatter()

        let output = formatter.format("xuống dòng ghi chú dấu hai chấm xong dấu chấm")

        XCTAssertEqual(output, "\nghi chú: xong.")
    }

    func test_preserves_normal_bilingual_prompt_text() {
        let formatter = TranscriptFormatter()

        let output = formatter.format("viet mot prompt about Swift concurrency")

        XCTAssertEqual(output, "viet mot prompt about Swift concurrency")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptFormatterTests`
Expected: FAIL because `TranscriptFormatter` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

public enum DictationSessionState: Equatable {
    case idle
    case recording
    case processing
    case success(String)
    case error(String)
}

public struct TranscriptFormatter {
    public init() {}

    public func format(_ transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        let replacements: [(String, String)] = [
            ("new line", "\n"),
            ("newline", "\n"),
            ("xuong dong", "\n"),
            ("xuống dòng", "\n"),
            ("dấu hai chấm", ":"),
            ("question mark", "?"),
            ("dấu phẩy", ","),
            ("dấu chấm", "."),
            ("dấu hỏi", "?"),
            ("comma", ","),
            ("period", "."),
            ("colon", ":")
        ]

        var output = trimmed
        for (source, target) in replacements.sorted(by: { $0.0.count > $1.0.count }) {
            output = output.replacingOccurrences(of: source, with: target)
        }

        output = output.replacingOccurrences(of: " \n", with: "\n")
        output = output.replacingOccurrences(of: "\n ", with: "\n")
        output = output.replacingOccurrences(of: " :", with: ":")
        output = output.replacingOccurrences(of: " ,", with: ",")
        output = output.replacingOccurrences(of: " .", with: ".")
        output = output.replacingOccurrences(of: " ?", with: "?")
        return output
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptFormatterTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AleVoiceCore/DictationSessionState.swift Sources/AleVoiceCore/TranscriptFormatter.swift tests/AleVoiceCoreTests/TranscriptFormatterTests.swift
git commit -m "Add transcript formatting rules"
```

### Task 2: Move recording flow to Auto-only and formatted output

**Files:**
- Modify: `Sources/AleVoiceCore/DictationSessionState.swift`
- Modify: `tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift`
- Modify: `tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift`
- Modify: `Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`

- [ ] **Step 1: Write the failing test**

```swift
@MainActor
func test_stopRecordingFormatsTranscriptBeforeDelivery() async throws {
    let outputProbe = TranscriptOutputProbe()
    let viewModel = TranscriptionDebugViewModel(
        startRecording: {},
        stopRecording: {
            AudioRecordingResult(audioURL: URL(fileURLWithPath: "/tmp/captured.wav"), byteCount: 4_096)
        },
        transcribe: { _, _, _ async throws in
            SpeechTranscriptionResult(
                engine: .funasr,
                modelIdentifier: "sensevoice-small",
                transcript: "new line benchmark summary colon faster period",
                latencyMs: 456
            )
        },
        deliverTranscript: { transcript in
            await outputProbe.record(transcript)
        }
    )

    await viewModel.startRecording()
    await viewModel.stopRecordingAndTranscribe(
        configURL: URL(fileURLWithPath: "/tmp/config.json")
    )

    let delivered = await outputProbe.transcripts()
    XCTAssertEqual(delivered, ["\nbenchmark summary: faster."])
}

@MainActor
func test_hotkeyReleaseAlwaysUsesAutoModeForMvp() async throws {
    let probe = TranscriptionProbe()
    let viewModel = TranscriptionDebugViewModel(
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

    await viewModel.startRecording()
    await viewModel.handleGlobalShortcutRelease(configURL: URL(fileURLWithPath: "/tmp/config.json"))

    let invocation = await probe.invocation()
    XCTAssertEqual(invocation?.mode, .auto)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionDebugViewModelTests --filter GlobalHotkeyDebugViewModelTests`
Expected: FAIL because the current view model still uses the provided mode and does not format recording output.

- [ ] **Step 3: Write minimal implementation**

```swift
import AleVoiceCore
import Combine
import Foundation

@MainActor
public final class TranscriptionDebugViewModel: ObservableObject {
    @Published public private(set) var sessionState: DictationSessionState = .idle
    @Published public private(set) var transcript: String = ""
    @Published public private(set) var latencyText: String = ""
    @Published public private(set) var errorText: String?
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var recordingStatusText: String = "Recorder idle"
    @Published public private(set) var permissionStatusText: String = "Microphone permission: unknown"
    @Published public private(set) var accessibilityStatusText: String = "Accessibility: unknown"
    @Published public var selectedMode: SpeechLanguageMode = .auto
    @Published public private(set) var inputMonitoringStatusText: String = "Input Monitoring: unknown"
    @Published public private(set) var shortcutDisplayText: String = "Dictation shortcut: not set"
    @Published public private(set) var shortcutCaptureText: String = ""
    @Published public private(set) var isCapturingShortcut: Bool = false

    private let microphonePermissionStatusClosure: @Sendable () async -> MicrophonePermissionStatus
    private let accessibilityPermissionStatusClosure: @Sendable () async -> AccessibilityPermissionStatus
    private let requestAccessibilityPermissionClosure: @Sendable () async -> AccessibilityPermissionStatus
    private let inputMonitoringPermissionStatusClosure: @Sendable () async -> InputMonitoringPermissionStatus
    private let requestInputMonitoringPermissionClosure: @Sendable () async -> InputMonitoringPermissionStatus
    private let loadShortcutClosure: @Sendable () -> DictationShortcut?
    private let saveShortcutClosure: @Sendable (DictationShortcut) throws -> Void
    private let beginShortcutCaptureClosure: @Sendable () async -> Result<DictationShortcut, DictationShortcutError>
    private let onShortcutChangeClosure: @Sendable (DictationShortcut?) -> Void
    private let startRecordingClosure: @Sendable () async throws -> Void
    private let stopRecordingClosure: @Sendable () async throws -> AudioRecordingResult
    private let transcriptFormatter: TranscriptFormatter
    private let transcribeClosure: @Sendable (URL, URL, SpeechLanguageMode) async throws -> SpeechTranscriptionResult
    private let deliverTranscriptClosure: @Sendable (String) async throws -> Void
    private var requestToken = 0
    private var pendingGlobalShortcutReleaseConfigURL: URL?
    private var isGlobalShortcutActivationStarting = false

    public init(
        microphonePermissionStatus: @escaping @Sendable () async -> MicrophonePermissionStatus = { .unknown },
        accessibilityPermissionStatus: @escaping @Sendable () async -> AccessibilityPermissionStatus = { .unknown },
        requestAccessibilityPermission: @escaping @Sendable () async -> AccessibilityPermissionStatus = { .unknown },
        inputMonitoringPermissionStatus: @escaping @Sendable () async -> InputMonitoringPermissionStatus = { .unknown },
        requestInputMonitoringPermission: @escaping @Sendable () async -> InputMonitoringPermissionStatus = { .unknown },
        loadShortcut: @escaping @Sendable () -> DictationShortcut? = { nil },
        beginShortcutCapture: @escaping @Sendable () async -> Result<DictationShortcut, DictationShortcutError> = {
            .failure(.missingModifier)
        },
        saveShortcut: @escaping @Sendable (DictationShortcut) throws -> Void = { _ in },
        onShortcutChange: @escaping @Sendable (DictationShortcut?) -> Void = { _ in },
        startRecording: @escaping @Sendable () async throws -> Void = {
            throw AudioRecorderError.captureFailed("recorder not configured")
        },
        stopRecording: @escaping @Sendable () async throws -> AudioRecordingResult = {
            throw AudioRecorderError.notRecording
        },
        transcriptFormatter: TranscriptFormatter = TranscriptFormatter(),
        transcribe: @escaping @Sendable (URL, URL, SpeechLanguageMode) async throws -> SpeechTranscriptionResult,
        deliverTranscript: @escaping @Sendable (String) async throws -> Void = { _ in }
    ) {
        self.microphonePermissionStatusClosure = microphonePermissionStatus
        self.accessibilityPermissionStatusClosure = accessibilityPermissionStatus
        self.requestAccessibilityPermissionClosure = requestAccessibilityPermission
        self.inputMonitoringPermissionStatusClosure = inputMonitoringPermissionStatus
        self.requestInputMonitoringPermissionClosure = requestInputMonitoringPermission
        self.loadShortcutClosure = loadShortcut
        self.saveShortcutClosure = saveShortcut
        self.beginShortcutCaptureClosure = beginShortcutCapture
        self.onShortcutChangeClosure = onShortcutChange
        self.startRecordingClosure = startRecording
        self.stopRecordingClosure = stopRecording
        self.transcriptFormatter = transcriptFormatter
        self.transcribeClosure = transcribe
        self.deliverTranscriptClosure = deliverTranscript
    }

    public func handleGlobalShortcutRelease(configURL: URL) async {
        guard !isCapturingShortcut else {
            return
        }
        if isGlobalShortcutActivationStarting {
            pendingGlobalShortcutReleaseConfigURL = configURL
            return
        }
        guard isRecording else {
            return
        }
        await stopRecordingAndTranscribe(configURL: configURL, mode: .auto)
    }

    public func stopRecordingAndTranscribe(configURL: URL, mode: SpeechLanguageMode = .auto) async {
        guard !isCapturingShortcut else {
            return
        }
        guard isRecording else {
            applyError(AudioRecorderError.notRecording)
            return
        }
        requestToken += 1
        let token = requestToken
        sessionState = .processing
        isRunning = true

        do {
            let recording = try await stopRecordingClosure()
            guard token == requestToken else { return }
            isRecording = false
            recordingStatusText = "Transcribing recording"

            let result = try await transcribeClosure(configURL, recording.audioURL, mode)
            guard token == requestToken else { return }
            let formattedTranscript = transcriptFormatter.format(result.transcript)
            transcript = formattedTranscript
            latencyText = "\(result.latencyMs) ms"
            recordingStatusText = "Last recording ready"

            try await deliverTranscriptClosure(formattedTranscript)
            errorText = nil
            isRunning = false
            sessionState = .success(formattedTranscript)
        } catch {
            guard token == requestToken else { return }
            isRecording = false
            recordingStatusText = "Recorder idle"
            transcript = ""
            latencyText = ""
            isRunning = false
            applyError(error)
        }
    }

    public func startRecording() async {
        guard !isCapturingShortcut else {
            return
        }

        isRunning = true
        do {
            try await startRecordingClosure()
            await refreshPermissionStatus()
            isRecording = true
            isRunning = false
            recordingStatusText = "Recording in progress"
            errorText = nil
            isGlobalShortcutActivationStarting = false
            sessionState = .recording

            if let pendingConfigURL = pendingGlobalShortcutReleaseConfigURL {
                pendingGlobalShortcutReleaseConfigURL = nil
                await stopRecordingAndTranscribe(configURL: pendingConfigURL, mode: .auto)
            }
        } catch {
            pendingGlobalShortcutReleaseConfigURL = nil
            await refreshPermissionStatus()
            isRecording = false
            isRunning = false
            recordingStatusText = "Recorder idle"
            isGlobalShortcutActivationStarting = false
            applyError(error)
        }
    }

    private func applyError(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        errorText = message
        sessionState = .error(message)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter TranscriptionDebugViewModelTests --filter GlobalHotkeyDebugViewModelTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AleVoiceAppUI/TranscriptionDebugViewModel.swift Sources/AleVoiceAppUI/ContentView.swift Sources/AleVoiceApp/AleVoiceApp.swift tests/AleVoiceAppUITests/TranscriptionDebugViewModelTests.swift tests/AleVoiceAppUITests/GlobalHotkeyDebugViewModelTests.swift
git commit -m "Make MVP dictation flow Auto-only"
```

### Task 3: Add menu bar controller state rendering

**Files:**
- Create: `tests/AleVoiceAppTests/MenuBarControllerTests.swift`
- Create: `Sources/AleVoiceApp/MenuBarController.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AleVoiceApp

final class MenuBarControllerTests: XCTestCase {
    @MainActor
    func test_menuBarSummaryUsesRecordingState() {
        let controller = MenuBarController(
            setTitle: { title in
                XCTAssertEqual(title, "AleVoice • Recording")
            }
        )

        controller.render(
            state: .recording,
            microphoneText: "Microphone permission: authorized",
            accessibilityText: "Accessibility: authorized",
            inputMonitoringText: "Input Monitoring: authorized",
            shortcutText: "Dictation shortcut: Control+Space"
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarControllerTests`
Expected: FAIL because `MenuBarController` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
import AppKit
import AleVoiceCore
import Foundation

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem?
    private let setTitle: (String) -> Void

    init(
        statusItem: NSStatusItem? = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        setTitle: @escaping (String) -> Void = { title in
            statusItem?.button?.title = title
        }
    ) {
        self.statusItem = statusItem
        self.setTitle = setTitle
    }

    func render(
        state: DictationSessionState,
        microphoneText: String,
        accessibilityText: String,
        inputMonitoringText: String,
        shortcutText: String
    ) {
        switch state {
        case .idle:
            setTitle("AleVoice")
        case .recording:
            setTitle("AleVoice • Recording")
        case .processing:
            setTitle("AleVoice • Processing")
        case .success:
            setTitle("AleVoice • Ready")
        case .error:
            setTitle("AleVoice • Error")
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarControllerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AleVoiceApp/MenuBarController.swift tests/AleVoiceAppTests/MenuBarControllerTests.swift Sources/AleVoiceApp/AleVoiceApp.swift
git commit -m "Add menu bar controller"
```

### Task 4: Add overlay controller and overlay state rendering

**Files:**
- Create: `tests/AleVoiceAppTests/OverlayWindowControllerTests.swift`
- Create: `Sources/AleVoiceApp/OverlayView.swift`
- Create: `Sources/AleVoiceApp/OverlayWindowController.swift`
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import AleVoiceApp
import AleVoiceCore

final class OverlayWindowControllerTests: XCTestCase {
    @MainActor
    func test_renderShowsRecordingOverlay() {
        var didShow = false
        let controller = OverlayWindowController(
            showWindow: { didShow = true },
            hideWindow: { XCTFail("hide should not be called") }
        )

        controller.render(state: .recording)

        XCTAssertTrue(didShow)
    }

    @MainActor
    func test_renderHidesOverlayWhenIdle() {
        var didHide = false
        let controller = OverlayWindowController(
            showWindow: { XCTFail("show should not be called") },
            hideWindow: { didHide = true }
        )

        controller.render(state: .idle)

        XCTAssertTrue(didHide)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter OverlayWindowControllerTests`
Expected: FAIL because `OverlayWindowController` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
import AppKit
import AleVoiceCore
import SwiftUI

@MainActor
final class OverlayWindowController {
    private let showWindowAction: () -> Void
    private let hideWindowAction: () -> Void

    init(
        showWindow: @escaping () -> Void = {},
        hideWindow: @escaping () -> Void = {}
    ) {
        self.showWindowAction = showWindow
        self.hideWindowAction = hideWindow
    }

    func render(state: DictationSessionState) {
        switch state {
        case .idle:
            hideWindowAction()
        case .recording, .processing, .success, .error:
            showWindowAction()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter OverlayWindowControllerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AleVoiceApp/OverlayView.swift Sources/AleVoiceApp/OverlayWindowController.swift tests/AleVoiceAppTests/OverlayWindowControllerTests.swift Sources/AleVoiceApp/AleVoiceApp.swift
git commit -m "Add dictation overlay controller"
```

### Task 5: Wire resident app behavior and menu-opened settings window

**Files:**
- Modify: `Sources/AleVoiceApp/AleVoiceApp.swift`
- Modify: `Sources/AleVoiceAppUI/ContentView.swift`
- Modify: `Sources/AleVoiceApp/MenuBarController.swift`
- Modify: `Sources/AleVoiceApp/OverlayWindowController.swift`
- Modify: `tests/AleVoiceAppTests/MenuBarControllerTests.swift`
- Modify: `tests/AleVoiceAppTests/OverlayWindowControllerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@MainActor
func test_menuBarSummaryUsesProcessingState() {
    let controller = MenuBarController(
        setTitle: { title in
            XCTAssertEqual(title, "AleVoice • Processing")
        }
    )

    controller.render(
        state: .processing,
        microphoneText: "Microphone permission: authorized",
        accessibilityText: "Accessibility: authorized",
        inputMonitoringText: "Input Monitoring: authorized",
        shortcutText: "Dictation shortcut: Control+Space"
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarControllerTests`
Expected: FAIL until the resident app rendering path covers processing and the app lifecycle is wired.

- [ ] **Step 3: Write minimal implementation**

```swift
@MainActor
@main
struct AleVoiceApp: App {
    @StateObject private var viewModel: TranscriptionDebugViewModel
    private let assetLocator: DebugAssetLocator
    private let hotkeyMonitor: QuartzHotkeyMonitor
    private let menuBarController: MenuBarController
    private let overlayController: OverlayWindowController

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        let audioRecorder = AudioRecorder()
        let shortcutStore = UserDefaultsDictationShortcutStore()
        let accessibilityPermission = AccessibilityPermission()
        let inputMonitoringPermission = QuartzInputMonitoringPermission()
        let shortcutCaptureController = QuartzShortcutCaptureController()
        let assetLocator = DebugAssetLocator()
        let hotkeyMonitor = QuartzHotkeyMonitor()
        let menuBarController = MenuBarController(openSettings: {
            NSApp.activate(ignoringOtherApps: true)
        })
        let overlayController = OverlayWindowController()
        let pasteOutput = ClipboardPasteTranscriptOutput(
            accessibilityStatus: { accessibilityPermission.status() }
        )
        let configURL = assetLocator.speechEngineConfigURL()
        let transcriptOutputService = TranscriptOutputService { transcript in
            try await pasteOutput.deliver(transcript)
        }

        let viewModel = TranscriptionDebugViewModel(
            microphonePermissionStatus: { await audioRecorder.microphonePermissionStatus() },
            accessibilityPermissionStatus: { accessibilityPermission.status() },
            requestAccessibilityPermission: { accessibilityPermission.requestAccess() },
            inputMonitoringPermissionStatus: {
                let status = inputMonitoringPermission.status()
                await MainActor.run {
                    status == .authorized ? hotkeyMonitor.start() : hotkeyMonitor.stop()
                }
                return status
            },
            requestInputMonitoringPermission: {
                let status = inputMonitoringPermission.requestAccess()
                await MainActor.run {
                    status == .authorized ? hotkeyMonitor.start() : hotkeyMonitor.stop()
                }
                return status
            },
            loadShortcut: { shortcutStore.load() },
            beginShortcutCapture: { await shortcutCaptureController.captureShortcut() },
            saveShortcut: { try shortcutStore.save($0) },
            onShortcutChange: { shortcut in
                MainActor.assumeIsolated {
                    hotkeyMonitor.updateShortcut(shortcut)
                }
            },
            startRecording: { try await audioRecorder.start() },
            stopRecording: { try await audioRecorder.stop() },
            transcribe: { configURL, audioURL, mode in
                try await Task.detached {
                    let settings = try SpeechEngineSettings.load(from: configURL)
                    let coordinator = TranscriptionCoordinator(settings: settings)
                    return try coordinator.transcribe(audioURL: audioURL, overrideMode: mode)
                }.value
            },
            deliverTranscript: { transcript in
                try await transcriptOutputService.deliver(transcript)
            }
        )

        hotkeyMonitor.onTransition = { transition in
            Task { @MainActor in
                switch transition {
                case .activated:
                    await viewModel.handleGlobalShortcutActivation()
                case .released:
                    await viewModel.handleGlobalShortcutRelease(configURL: configURL)
                }
            }
        }

        hotkeyMonitor.updateShortcut(shortcutStore.load())
        if inputMonitoringPermission.status() == .authorized {
            hotkeyMonitor.start()
        }

        _viewModel = StateObject(wrappedValue: viewModel)
        self.assetLocator = assetLocator
        self.hotkeyMonitor = hotkeyMonitor
        self.menuBarController = menuBarController
        self.overlayController = overlayController
    }

    var body: some Scene {
        Window("AleVoice Settings", id: "settings") {
            ContentView(viewModel: viewModel, assetLocator: assetLocator)
                .onReceive(viewModel.$sessionState) { state in
                    menuBarController.render(
                        state: state,
                        microphoneText: viewModel.permissionStatusText,
                        accessibilityText: viewModel.accessibilityStatusText,
                        inputMonitoringText: viewModel.inputMonitoringStatusText,
                        shortcutText: viewModel.shortcutDisplayText
                    )
                    overlayController.render(state: state)
                }
        }
        .defaultSize(width: 560, height: 320)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test --filter MenuBarControllerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/AleVoiceApp/AleVoiceApp.swift Sources/AleVoiceAppUI/ContentView.swift tests/AleVoiceAppTests/MenuBarControllerTests.swift tests/AleVoiceAppTests/OverlayWindowControllerTests.swift
git commit -m "Wire resident menu bar app lifecycle"
```

### Task 6: Update product docs and validation evidence

**Files:**
- Modify: `docs/product/local-dictation-workflow.md`
- Modify: `docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md`
- Modify: `docs/validation/us-006-paste-transcript-into-focused-app.md`
- Modify: `README.md`

- [ ] **Step 1: Write the failing doc assertions**

```text
1. `docs/product/local-dictation-workflow.md` should still say "native debug app locally".
2. `README.md` should still describe the generic Harness repo.
3. `US-006` docs should still mention manual paste proof pending.
4. Overlay and formatting should still appear as prior out-of-scope or missing behavior.
```

- [ ] **Step 2: Run review to verify docs are stale**

Run: `rtk rg -n "Harness v0|Language mode|Overlay UI|Formatting-command normalization|menu bar" README.md docs/product/local-dictation-workflow.md docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md docs/validation/us-006-paste-transcript-into-focused-app.md`
Expected: output shows stale generic Harness README text and out-of-scope references for overlay/formatting.

- [ ] **Step 3: Write minimal implementation**

```text
- Rewrite `docs/product/local-dictation-workflow.md` so the workflow begins with a resident menu bar app and uses Auto-only dictation.
- Update `docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md` with completed manual focused-field paste proof and remove the pending note.
- Update `docs/validation/us-006-paste-transcript-into-focused-app.md` with exact TextEdit plus second-field observations.
- Replace the root `README.md` opening sections with AleVoice product overview, prerequisites, key commands, local validation flow, and current MVP status.
```

- [ ] **Step 4: Run review to verify docs match MVP**

Run: `rtk rg -n "resident menu bar|Auto-only|overlay|formatting|AleVoice" README.md docs/product/local-dictation-workflow.md docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md docs/validation/us-006-paste-transcript-into-focused-app.md`
Expected: output reflects AleVoice product docs instead of generic Harness text.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/product/local-dictation-workflow.md docs/stories/epics/E01-local-stt/US-006-paste-transcript-into-focused-app.md docs/validation/us-006-paste-transcript-into-focused-app.md
git commit -m "Align docs with menu bar MVP"
```

### Task 7: Verify, record evidence, and close story

**Files:**
- Modify: `docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/validation.md`
- Modify: `harness.db`

- [ ] **Step 1: Run automated verification**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer rtk swift test`
Expected: PASS with full suite green.

- [ ] **Step 2: Run story verification command**

Run: `rtk ./scripts/bin/harness-cli story update --id US-007 --unit 1 --integration 1 --e2e 0 --platform 1 --status implemented --evidence "Automated tests passed; menu bar and overlay validated locally; focused TextEdit and second field paste proof recorded."`
Expected: story row updated.

- [ ] **Step 3: Run platform validation**

```text
1. Launch the app bundle with scripts/run-alevoice-app.
2. Verify menu bar presence.
3. Open settings/debug window from menu.
4. Verify overlay appears during recording and processing.
5. Paste dictation into TextEdit.
6. Paste dictation into Notes or a browser text field.
7. Record exact observed results in validation.md and updated US-006 evidence.
```

- [ ] **Step 4: Run story verify to confirm durable proof**

Run: `rtk ./scripts/bin/harness-cli story verify US-007`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp/validation.md harness.db docs/stories/epics/E01-local-stt/US-007-menu-bar-mvp
git commit -m "Record menu bar MVP validation evidence"
```

## Self-Review

- Spec coverage: menu bar residency, Auto-only workflow, overlay, formatting normalization, paste proof, and docs alignment all map to Tasks 1-7.
- Placeholder scan: no `TODO`, `TBD`, or vague implementation placeholders remain; open evidence is named only in validation steps that are intentionally executed later.
- Type consistency: `TranscriptFormatter`, `DictationSessionState`, `MenuBarController`, and `OverlayWindowController` use consistent names across tasks.
