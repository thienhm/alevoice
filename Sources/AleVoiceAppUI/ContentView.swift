import AleVoiceCore
import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel: TranscriptionDebugViewModel

    public init(viewModel: TranscriptionDebugViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Transcribe en-001 sample") {
                Task {
                    await viewModel.runSample(
                        configURL: URL(fileURLWithPath: "Config/speech-engine.json"),
                        audioURL: URL(fileURLWithPath: "data/benchmarks/samples/en-001.wav"),
                        mode: .auto
                    )
                }
            }
            .disabled(viewModel.isRunning)

            Text(viewModel.latencyText)
            Text(viewModel.transcript)
                .textSelection(.enabled)

            if let errorText = viewModel.errorText {
                Text(errorText)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 220)
    }
}
