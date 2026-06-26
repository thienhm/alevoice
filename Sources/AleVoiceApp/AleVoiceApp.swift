import AleVoiceAppUI
import AleVoiceCore
import SwiftUI

@main
struct AleVoiceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: TranscriptionDebugViewModel(
                    transcribe: { configURL, audioURL, mode in
                        try await Task.detached {
                            let settings = try SpeechEngineSettings.load(from: configURL)
                            let coordinator = TranscriptionCoordinator(settings: settings)
                            return try coordinator.transcribe(audioURL: audioURL, overrideMode: mode)
                        }.value
                    }
                )
            )
        }
    }
}
