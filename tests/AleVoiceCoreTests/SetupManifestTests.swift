import XCTest
@testable import AleVoiceCLI

final class SetupManifestTests: XCTestCase {
    func test_loadsPinnedFunASRSenseVoiceManifest() throws {
        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-sensevoice.json")
        )

        XCTAssertEqual(manifest.id, "funasr-sensevoice")
        XCTAssertEqual(manifest.displayName, "FunASR SenseVoice")
        XCTAssertEqual(manifest.engineKind, "funasr")
        XCTAssertEqual(manifest.defaultVariant, "f16")
        XCTAssertEqual(try manifest.variant(named: nil).configTemplate.supportedModes, [.auto])
        XCTAssertEqual(try manifest.variant(named: nil).models.map(\.relativePath), ["sensevoice-small-f16.gguf"])
    }

    func test_loadsPinnedFunASRNanoManifest() throws {
        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-nano.json")
        )

        let variant = try manifest.variant(named: nil)

        XCTAssertEqual(manifest.id, "funasr-nano")
        XCTAssertEqual(manifest.displayName, "FunASR Nano")
        XCTAssertEqual(manifest.engineKind, "funasr")
        XCTAssertEqual(manifest.defaultVariant, "q4km")
        XCTAssertEqual(variant.configTemplate.defaultMode, .auto)
        XCTAssertEqual(variant.configTemplate.supportedModes, [.auto, .en])
        XCTAssertEqual(variant.runtime.binaryRelativePath, "llama-funasr-cli")
        XCTAssertEqual(variant.models.map(\.relativePath), ["qwen3-0.6b-q4km.gguf"])
        XCTAssertEqual(variant.auxiliaryModels["encoder"]?.relativePath, "funasr-encoder-f16.gguf")
    }

    func test_loadsPinnedFunASRMLTNanoManifest() throws {
        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-mlt-nano.json")
        )

        let variant = try manifest.variant(named: nil)

        XCTAssertEqual(manifest.id, "funasr-mlt-nano")
        XCTAssertEqual(manifest.displayName, "FunASR MLT Nano")
        XCTAssertEqual(manifest.engineKind, "funasr")
        XCTAssertEqual(manifest.defaultVariant, "q8")
        XCTAssertEqual(variant.configTemplate.defaultMode, .auto)
        XCTAssertEqual(variant.configTemplate.supportedModes, [.auto, .en, .vi])
        XCTAssertEqual(variant.configTemplate.runtimeProfile, .crispASRFunASR)
        XCTAssertEqual(variant.runtime.binaryRelativePath, "crispasr-macos/crispasr")
        XCTAssertEqual(variant.models.map(\.relativePath), ["funasr-mlt-nano-2512-q8_0.gguf"])
        XCTAssertEqual(variant.models.first?.sha256, "29d9ccaea032650bc747a33947f65f940bcbcf019d9f11471e4e8e0d7bab1b04")
    }

    func test_resolvesMacOSArm64RuntimeArtifact() throws {
        let manifest = try SetupManifest.load(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Config/engines/funasr-sensevoice.json")
        )

        let runtime = try manifest.variant(named: "f16").runtimeArtifact(for: .macOSArm64)

        XCTAssertEqual(
            runtime.url.absoluteString,
            "https://github.com/modelscope/FunASR/releases/download/runtime-llamacpp-v0.1.2/funasr-llamacpp-macos-arm64.tar.gz"
        )
        XCTAssertEqual(runtime.sha256, "50a36463372eb87adf9e0829aa62b29ce94d7ba84ded705b9e81c768c274d923")
        XCTAssertEqual(runtime.binaryRelativePath, "llama-funasr-sensevoice")
        XCTAssertEqual(runtime.unpack, .tarGzip)
    }

    func test_manifestRejectsMissingChecksum() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bad-setup-manifest.json")
        try """
        {
          "id": "bad",
          "displayName": "Bad",
          "description": "Bad fixture",
          "engineKind": "funasr",
          "defaultVariant": "default",
          "variants": {
            "default": {
              "runtime": {
                "platforms": {
                  "macos-arm64": {
                    "url": "https://example.com/runtime.tar.gz",
                    "sha256": ""
                  }
                },
                "unpack": "tar.gz",
                "binaryRelativePath": "runtime"
              },
              "models": [
                {
                  "id": "main",
                  "url": "https://example.com/model.gguf",
                  "sha256": "abc",
                  "relativePath": "model.gguf"
                }
              ],
              "configTemplate": { "defaultMode": "auto" }
            }
          }
        }
        """.write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SetupManifest.load(from: url)) { error in
            XCTAssertEqual(
                error as? SetupManifestError,
                .invalidManifest("runtime macos-arm64 sha256 must be non-empty")
            )
        }
    }
}
