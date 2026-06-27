import Foundation

@MainActor
final class MenuBarShellModel: ObservableObject {
    @Published var title: String
    @Published var isRecordingIndicatorVisible: Bool

    init(
        title: String = "AleVoice",
        isRecordingIndicatorVisible: Bool = false
    ) {
        self.title = title
        self.isRecordingIndicatorVisible = isRecordingIndicatorVisible
    }
}
