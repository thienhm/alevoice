import AleVoiceCore
import AppKit
import Foundation

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem?
    private let setTitle: (String) -> Void

    init(
        statusItem: NSStatusItem? = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        setTitle: ((String) -> Void)? = nil
    ) {
        self.statusItem = statusItem
        self.setTitle = setTitle ?? { [weak statusItem] title in
            statusItem?.button?.title = title
        }
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
