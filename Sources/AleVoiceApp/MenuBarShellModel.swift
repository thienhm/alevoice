import Foundation

@MainActor
final class MenuBarShellModel: ObservableObject {
    @Published var title: String

    init(title: String = "AleVoice") {
        self.title = title
    }
}
