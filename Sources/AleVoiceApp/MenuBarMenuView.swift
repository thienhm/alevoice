import AleVoiceAppUI
import AppKit
import SwiftUI

struct MenuBarMenuView: View {
    @ObservedObject var viewModel: TranscriptionDebugViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statusText)
                .font(.system(size: 12, weight: .semibold))
            Text(viewModel.permissionStatusText)
                .font(.system(size: 11))
            Text(viewModel.accessibilityStatusText)
                .font(.system(size: 11))
            Text(viewModel.inputMonitoringStatusText)
                .font(.system(size: 11))
            Text(viewModel.shortcutDisplayText)
                .font(.system(size: 11))
        }
        .padding(.bottom, 6)

        Divider()

        Button("Open Settings") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit AleVoice") {
            NSApp.terminate(nil)
        }
    }

    private var statusText: String {
        switch viewModel.sessionState {
        case .idle:
            return "Idle"
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .success:
            return "Ready"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
