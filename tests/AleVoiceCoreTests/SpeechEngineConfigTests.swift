import XCTest
@testable import AleVoiceCore

final class SpeechEngineConfigTests: XCTestCase {
    func test_loadReadsNewSelectedEngineShape() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-new-shape.json")
        try """
        {
          "selectedEngine": "funasr-sensevoice",
          "selectedMode": "auto",
          "engines": {
            "funasr-sensevoice": {
              "engineKind": "funasr",
              "displayName": "FunASR SenseVoice",
              "binaryPath": "/tmp/managed/llama-funasr-sensevoice",
              "modelPath": "/tmp/managed/sensevoice-small-f16.gguf",
              "defaultMode": "auto",
              "supportedModes": ["auto"]
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
        XCTAssertEqual(settings.selectedMode, .auto)
        XCTAssertEqual(settings.selectedEngineConfig.displayName, "FunASR SenseVoice")
        XCTAssertEqual(settings.selectedEngineConfig.supportedModes, [.auto])
    }

    func test_loadReadsSelectedModeAndSupportedModes() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-selected-mode.json")
        try """
        {
          "selectedEngine": "funasr-nano",
          "selectedMode": "vi",
          "engines": {
            "funasr-nano": {
              "engineKind": "funasr",
              "displayName": "FunASR Nano",
              "binaryPath": "/tmp/managed/llama-funasr-cli",
              "modelPath": "/tmp/managed/qwen3-0.6b-q4km.gguf",
              "auxiliaryModelPaths": {
                "encoder": "/tmp/managed/funasr-encoder-f16.gguf"
              },
              "defaultMode": "auto",
              "supportedModes": ["auto", "en", "vi"]
            }
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        let settings = try SpeechEngineSettings.load(from: url)

        XCTAssertEqual(settings.selectedEngineID, "funasr-nano")
        XCTAssertEqual(settings.selectedMode, .vi)
        XCTAssertEqual(settings.selectedEngineConfig.displayName, "FunASR Nano")
        XCTAssertEqual(settings.selectedEngineConfig.supportedModes, [.auto, .en, .vi])
        XCTAssertEqual(settings.selectedEngineConfig.auxiliaryModelPaths["encoder"], "/tmp/managed/funasr-encoder-f16.gguf")
        XCTAssertEqual(settings.funasr.auxiliaryModelPaths["encoder"], "/tmp/managed/funasr-encoder-f16.gguf")
    }

    func test_loadRejectsSelectedModeUnsupportedBySelectedEngine() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-unsupported-selected-mode.json")
        try """
        {
          "selectedEngine": "funasr-sensevoice",
          "selectedMode": "vi",
          "engines": {
            "funasr-sensevoice": {
              "engineKind": "funasr",
              "binaryPath": "/tmp/managed/llama-funasr-sensevoice",
              "modelPath": "/tmp/managed/sensevoice-small-f16.gguf",
              "defaultMode": "auto",
              "supportedModes": ["auto"]
            }
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SpeechEngineSettings.load(from: url)) { error in
            XCTAssertEqual(
                error as? SpeechEngineError,
                .invalidConfiguration("selectedMode 'vi' must be supported by selectedEngine 'funasr-sensevoice'")
            )
        }
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
        XCTAssertEqual(settings.selectedMode, .auto)
        XCTAssertEqual(settings.selectedEngineConfig.supportedModes, [.auto])
    }

    func test_savePersistsNewSelectedEngineShape() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-save-new-shape.json")
        let settings = SpeechEngineSettings(
            selectedEngineID: "funasr-sensevoice",
            selectedMode: .auto,
            engines: [
                "funasr-sensevoice": EngineInstallConfig(
                    engineKind: .funasr,
                    displayName: "FunASR SenseVoice",
                    binaryPath: "/tmp/managed/runtime/llama-funasr-sensevoice",
                    modelPath: "/tmp/managed/models/sensevoice-small-f16.gguf",
                    defaultMode: .auto,
                    supportedModes: [.auto]
                ),
            ]
        )

        try settings.save(to: url)
        let raw = try String(contentsOf: url, encoding: .utf8)
        let loaded = try SpeechEngineSettings.load(from: url)

        XCTAssertTrue(raw.contains(#""selectedEngine" : "funasr-sensevoice""#))
        XCTAssertTrue(raw.contains(#""selectedMode" : "auto""#))
        XCTAssertTrue(raw.contains(#""displayName" : "FunASR SenseVoice""#))
        XCTAssertTrue(raw.contains(#""supportedModes" : ["#))
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

    func test_loadAllowsExplicitDefaultModeWhenSupportedByEngine() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("speech-engine-unsupported-mode.json")
        try """
        {
          "selectedEngine": "funasr-nano",
          "selectedMode": "en",
          "engines": {
            "funasr-nano": {
              "engineKind": "funasr",
              "binaryPath": "/tmp/funasr",
              "modelPath": "/tmp/funasr.gguf",
              "defaultMode": "en",
              "supportedModes": ["auto", "en", "vi"]
            }
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        let settings = try SpeechEngineSettings.load(from: url)

        XCTAssertEqual(settings.selectedMode, .en)
        XCTAssertEqual(settings.funasr.defaultMode, .en)
    }

    func test_engineKindIsFunASROnlyForInitialNativeCore() {
        XCTAssertNil(SpeechEngineKind(rawValue: "whispercpp"))
    }
}
