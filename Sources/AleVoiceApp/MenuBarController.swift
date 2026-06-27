import AleVoiceCore
import AppKit
import Foundation

struct MenuBarPresentation: Equatable {
    let title: String
    let isRecordingIndicatorVisible: Bool
}

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem?
    private let updateShell: (MenuBarPresentation) -> Void

    init(
        statusItem: NSStatusItem? = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        updateShell: ((MenuBarPresentation) -> Void)? = nil
    ) {
        self.statusItem = statusItem
        self.updateShell = updateShell ?? { [weak statusItem] presentation in
            statusItem?.button?.title = presentation.title
            statusItem?.button?.contentTintColor = presentation.isRecordingIndicatorVisible ? .systemRed : nil
        }
    }

    func render(
        state: DictationSessionState,
        microphoneText: String,
        accessibilityText: String,
        inputMonitoringText: String,
        shortcutText: String
    ) {
        updateShell(Self.presentation(for: state))
    }

    static func presentation(for state: DictationSessionState) -> MenuBarPresentation {
        switch state {
        case .idle:
            return MenuBarPresentation(title: "AleVoice", isRecordingIndicatorVisible: false)
        case .recording:
            return MenuBarPresentation(title: "AleVoice • Recording", isRecordingIndicatorVisible: true)
        case .processing:
            return MenuBarPresentation(title: "AleVoice • Processing", isRecordingIndicatorVisible: false)
        case .success:
            return MenuBarPresentation(title: "AleVoice • Ready", isRecordingIndicatorVisible: false)
        case .error:
            return MenuBarPresentation(title: "AleVoice • Error", isRecordingIndicatorVisible: false)
        }
    }
}
