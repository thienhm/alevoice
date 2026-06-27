import AleVoiceCore
import SwiftUI

struct OverlayView: View {
    let state: DictationSessionState

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var text: String {
        switch state {
        case .idle:
            return ""
        case .recording:
            return "Recording"
        case .processing:
            return "Processing"
        case .success:
            return "Pasted"
        case .error(let message):
            return message
        }
    }

    private var color: Color {
        switch state {
        case .idle:
            return .clear
        case .recording:
            return .red
        case .processing:
            return .yellow
        case .success:
            return .green
        case .error:
            return .orange
        }
    }
}
