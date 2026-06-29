import XCTest
@testable import AleVoiceCore

final class SpeechEngineConfigTests: XCTestCase {
    func test_loadReadsNewSelectedEngineShape() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-new-shape.json")
        try """
        {
          "selectedEngine": "funasr-sensevoice",
          "engines": {
            "funasr-sensevoice": {
              "engineKind": "funasr",
              "binaryPath": "/tmp/managed/llama-funasr-sensevoice",
              "modelPath": "/tmp/managed/sensevoice-small-f16.gguf",
              "defaultMode": "auto"
            }
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        let settings = try SpeechEngineSettings.load(from: url)

        XCTAssertEqual(settings.selectedEngineID, "funasr-sensevoice")
        XCTAssertEqual(settings.engine, .funasr)
        XCTAssertEqual(settings.funasr.binaryPath, "/tmp/managed/llama-funasr-sensevoice")
        XCTAssertEqual(settings.funasr.modelPath, "/tmp/managed/sensevoice-small-f16.gguf")
        XCTAssertEqual(settings.funasr.defaultMode, .auto)
    }

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

        XCTAssertEqual(settings.selectedEngineID, "funasr")
        XCTAssertEqual(settings.engine, .funasr)
        XCTAssertEqual(settings.funasr.binaryPath, "/tmp/funasr")
        XCTAssertEqual(settings.funasr.defaultMode, .auto)
    }

    func test_savePersistsNewSelectedEngineShape() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-save-new-shape.json")
        let settings = SpeechEngineSettings(
            selectedEngineID: "funasr-sensevoice",
            engines: [
                "funasr-sensevoice": EngineInstallConfig(
                    engineKind: .funasr,
                    binaryPath: "/tmp/managed/runtime/llama-funasr-sensevoice",
                    modelPath: "/tmp/managed/models/sensevoice-small-f16.gguf",
                    defaultMode: .auto
                ),
            ]
        )

        try settings.save(to: url)
        let raw = try String(contentsOf: url, encoding: .utf8)
        let loaded = try SpeechEngineSettings.load(from: url)

        XCTAssertTrue(raw.contains(#""selectedEngine" : "funasr-sensevoice""#))
        XCTAssertEqual(loaded, settings)
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
