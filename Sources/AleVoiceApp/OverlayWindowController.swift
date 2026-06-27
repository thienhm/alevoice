import AleVoiceCore
import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private var panel: NSPanel?
    private let showWindowAction: () -> Void
    private let hideWindowAction: () -> Void

    init(
        showWindow: (() -> Void)? = nil,
        hideWindow: (() -> Void)? = nil
    ) {
        self.showWindowAction = showWindow ?? {}
        self.hideWindowAction = hideWindow ?? {}
    }

    func render(state: DictationSessionState) {
        switch state {
        case .idle:
            hideWindowAction()
            panel?.orderOut(nil)
        case .recording, .processing, .success, .error:
            showWindowAction()
            showPanel(for: state)
        }
    }

    private func showPanel(for state: DictationSessionState) {
        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(rootView: OverlayView(state: state))
        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let panelFrame = panel.frame
        let origin = NSPoint(
            x: screenFrame.midX - panelFrame.width / 2,
            y: screenFrame.maxY - panelFrame.height - 32
        )
        panel.setFrameOrigin(origin)
    }
}
