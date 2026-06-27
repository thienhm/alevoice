import AleVoiceAppUI
import AleVoiceCore
import AppKit
import Combine
import SwiftUI

@MainActor
@main
struct AleVoiceApp: App {
    @StateObject private var viewModel: TranscriptionDebugViewModel
    @StateObject private var shellModel: MenuBarShellModel
    private let assetLocator: DebugAssetLocator
    private let hotkeyMonitor: QuartzHotkeyMonitor
    private let menuBarController: MenuBarController
    private let overlayController: OverlayWindowController
    private let sessionStateObserver: AnyCancellable

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        let audioRecorder = AudioRecorder()
        let shortcutStore = UserDefaultsDictationShortcutStore()
        let accessibilityPermission = AccessibilityPermission()
        let inputMonitoringPermission = QuartzInputMonitoringPermission()
        let shortcutCaptureController = QuartzShortcutCaptureController()
        let assetLocator = DebugAssetLocator()
        let hotkeyMonitor = QuartzHotkeyMonitor()
        let shellModel = MenuBarShellModel()
        let menuBarController = MenuBarController(
            statusItem: nil,
            setTitle: { title in
                shellModel.title = title
            }
        )
        let overlayController = OverlayWindowController()
        let pasteOutput = ClipboardPasteTranscriptOutput(
            accessibilityStatus: { accessibilityPermission.status() }
        )
        let configURL = assetLocator.speechEngineConfigURL()
        let transcriptOutputService = TranscriptOutputService { transcript in
            try await pasteOutput.deliver(transcript)
        }

        let viewModel = TranscriptionDebugViewModel(
            microphonePermissionStatus: {
                await audioRecorder.microphonePermissionStatus()
            },
            accessibilityPermissionStatus: {
                accessibilityPermission.status()
            },
            requestAccessibilityPermission: {
                accessibilityPermission.requestAccess()
            },
            inputMonitoringPermissionStatus: {
                let status = inputMonitoringPermission.status()
                await MainActor.run {
                    if status == .authorized {
                        hotkeyMonitor.start()
                    } else {
                        hotkeyMonitor.stop()
                    }
                }
                return status
            },
            requestInputMonitoringPermission: {
                let status = inputMonitoringPermission.requestAccess()
                await MainActor.run {
                    if status == .authorized {
                        hotkeyMonitor.start()
                    } else {
                        hotkeyMonitor.stop()
                    }
                }
                return status
            },
            loadShortcut: {
                shortcutStore.load()
            },
            beginShortcutCapture: {
                await shortcutCaptureController.captureShortcut()
            },
            saveShortcut: {
                try shortcutStore.save($0)
            },
            onShortcutChange: { shortcut in
                MainActor.assumeIsolated {
                    hotkeyMonitor.updateShortcut(shortcut)
                }
            },
            startRecording: {
                try await audioRecorder.start()
            },
            stopRecording: {
                try await audioRecorder.stop()
            },
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

        let sessionStateObserver = viewModel.$sessionState.sink { state in
            menuBarController.render(
                state: state,
                microphoneText: viewModel.permissionStatusText,
                accessibilityText: viewModel.accessibilityStatusText,
                inputMonitoringText: viewModel.inputMonitoringStatusText,
                shortcutText: viewModel.shortcutDisplayText
            )
            overlayController.render(state: state)
        }
        menuBarController.render(
            state: viewModel.sessionState,
            microphoneText: viewModel.permissionStatusText,
            accessibilityText: viewModel.accessibilityStatusText,
            inputMonitoringText: viewModel.inputMonitoringStatusText,
            shortcutText: viewModel.shortcutDisplayText
        )

        _viewModel = StateObject(wrappedValue: viewModel)
        _shellModel = StateObject(wrappedValue: shellModel)
        self.assetLocator = assetLocator
        self.hotkeyMonitor = hotkeyMonitor
        self.menuBarController = menuBarController
        self.overlayController = overlayController
        self.sessionStateObserver = sessionStateObserver
    }

    var body: some Scene {
        MenuBarExtra(shellModel.title, systemImage: "waveform") {
            MenuBarMenuView(viewModel: viewModel)
        }

        Window("AleVoice Settings", id: "settings") {
            ContentView(viewModel: viewModel, assetLocator: assetLocator)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    hotkeyMonitor.stop()
                }
        }
        .defaultSize(width: 560, height: 320)
    }
}
