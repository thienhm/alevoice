import AleVoiceAppUI
import AleVoiceCore
import AppKit
import SwiftUI

struct MenuBarMenuView: View {
    @ObservedObject var viewModel: TranscriptionDebugViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let lines = menuStatusLines(
                statusText: statusText,
                isDictationEnabled: viewModel.isDictationEnabled,
                shortcutText: viewModel.shortcutDisplayText
            )
            Text(lines[0])
                .font(.system(size: 12, weight: .semibold))
            Toggle("Enabled", isOn: Binding(
                get: { viewModel.isDictationEnabled },
                set: { viewModel.setDictationEnabled($0) }
            ))
            .disabled(!viewModel.canToggleDictationEnabled)
            Text(lines[2])
                .font(.system(size: 11))
        }
        .padding(.bottom, 6)

        if let errorMessage = lastErrorMessage(from: viewModel.sessionState) {
            Button("Copy Last Error") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(errorMessage, forType: .string)
            }
        }

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

@MainActor
func lastErrorMessage(from state: DictationSessionState) -> String? {
    guard case .error(let message) = state else {
        return nil
    }
    return message
}

@MainActor
func menuStatusLines(
    statusText: String,
    isDictationEnabled: Bool,
    shortcutText: String
) -> [String] {
    [
        statusText,
        isDictationEnabled ? "Enabled" : "Disabled",
        shortcutText
    ]
}
