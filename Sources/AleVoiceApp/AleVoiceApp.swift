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
            updateShell: { presentation in
                shellModel.title = presentation.title
                shellModel.isRecordingIndicatorVisible = presentation.isRecordingIndicatorVisible
            }
        )
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
            requestMicrophonePermission: {
                await audioRecorder.requestMicrophonePermission()
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
            openAccessibilitySettings: {
                PermissionSettingsOpener.openAccessibility()
            },
            openInputMonitoringSettings: {
                PermissionSettingsOpener.openInputMonitoring()
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
        if let settings = try? SpeechEngineSettings.load(from: configURL) {
            viewModel.applySpeechEngineSettings(settings)
        }

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
        self.sessionStateObserver = sessionStateObserver
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView(viewModel: viewModel)
        } label: {
            Label {
                Text(shellModel.title)
            } icon: {
                Image(systemName: "waveform")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(shellModel.isRecordingIndicatorVisible ? Color.red : Color.primary)
            }
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

private enum PermissionSettingsOpener {
    private static let accessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    private static let inputMonitoringURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!

    static func openAccessibility(workspace: NSWorkspace = .shared) {
        workspace.open(accessibilityURL)
    }

    static func openInputMonitoring(workspace: NSWorkspace = .shared) {
        workspace.open(inputMonitoringURL)
    }
}
