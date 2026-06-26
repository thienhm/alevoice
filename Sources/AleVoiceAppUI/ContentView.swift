import AleVoiceCore
import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel: TranscriptionDebugViewModel
    @State private var selectedMode: SpeechLanguageMode = .auto
    private let configURL: URL
    private let sampleAudioURL: URL

    public init(
        viewModel: TranscriptionDebugViewModel,
        assetLocator: DebugAssetLocator = DebugAssetLocator()
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.configURL = assetLocator.speechEngineConfigURL()
        self.sampleAudioURL = assetLocator.englishSampleAudioURL()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(viewModel.permissionStatusText)
                Button("Refresh permission status") {
                    Task {
                        await viewModel.refreshPermissionStatus()
                    }
                }
            }

            Picker("Language mode", selection: $selectedMode) {
                Text("Auto").tag(SpeechLanguageMode.auto)
                Text("English").tag(SpeechLanguageMode.en)
                Text("Vietnamese").tag(SpeechLanguageMode.vi)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button("Start microphone capture") {
                    Task {
                        await viewModel.startRecording()
                    }
                }
                .disabled(viewModel.isRunning || viewModel.isRecording)

                Button("Stop and transcribe recording") {
                    Task {
                        await viewModel.stopRecordingAndTranscribe(
                            configURL: configURL,
                            mode: selectedMode
                        )
                    }
                }
                .disabled(viewModel.isRunning || !viewModel.isRecording)
            }

            Button("Transcribe en-001 sample") {
                Task {
                    await viewModel.runSample(
                        configURL: configURL,
                        audioURL: sampleAudioURL,
                        mode: .auto
                    )
                }
            }
            .disabled(viewModel.isRunning || viewModel.isRecording)

            Text(viewModel.recordingStatusText)
            Text(viewModel.latencyText)
            Text(viewModel.transcript)
                .textSelection(.enabled)

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 260)
        .task {
            await viewModel.refreshPermissionStatus()
        }
    }
}
