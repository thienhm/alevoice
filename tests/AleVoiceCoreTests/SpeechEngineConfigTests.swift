import XCTest
@testable import AleVoiceCore

final class SpeechEngineConfigTests: XCTestCase {
    func test_loadDefaultsToFunASR() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine.json")
        try """
        {
          "engine": "funasr",
          "funasr": {
            "binaryPath": "/tmp/funasr",
            "modelPath": "/tmp/funasr.gguf",
            "defaultMode": "auto"
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        let settings = try SpeechEngineSettings.load(from: url)

        XCTAssertEqual(settings.engine, .funasr)
        XCTAssertEqual(settings.funasr.binaryPath, "/tmp/funasr")
        XCTAssertEqual(settings.funasr.defaultMode, .auto)
    }

    func test_loadRejectsMissingSelectedEngineBinaryPath() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-bad.json")
        try """
        {
          "engine": "funasr",
          "funasr": {
            "binaryPath": "",
            "modelPath": "/tmp/funasr.gguf",
            "defaultMode": "vi"
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SpeechEngineSettings.load(from: url))
    }

    func test_loadRejectsUnsupportedFunASRDefaultMode() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-unsupported-mode.json")
        try """
        {
          "engine": "funasr",
          "funasr": {
            "binaryPath": "/tmp/funasr",
            "modelPath": "/tmp/funasr.gguf",
            "defaultMode": "en"
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SpeechEngineSettings.load(from: url)) { error in
            XCTAssertEqual(
                error as? SpeechEngineError,
                .invalidConfiguration("funasr runtime only supports defaultMode 'auto' in current local runtime")
            )
        }
    }

    func test_engineKindIsFunASROnlyForInitialNativeCore() {
        XCTAssertNil(SpeechEngineKind(rawValue: "whispercpp"))
    }
}
