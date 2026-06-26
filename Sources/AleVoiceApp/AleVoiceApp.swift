import AleVoiceAppUI
import AleVoiceCore
import AppKit
import SwiftUI

@main
struct AleVoiceApp: App {
    private let audioRecorder = AudioRecorder()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: TranscriptionDebugViewModel(
                    microphonePermissionStatus: {
                        await audioRecorder.microphonePermissionStatus()
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
                    }
                )
            )
        }
    }
}
