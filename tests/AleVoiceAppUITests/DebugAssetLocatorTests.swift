import XCTest
@testable import AleVoiceAppUI

final class DebugAssetLocatorTests: XCTestCase {
    func test_speechEngineConfigURLPrefersCurrentDirectoryWhenFileExists() throws {
        let root = try makeDirectory(named: "cwd-root")
        let configURL = root
            .appendingPathComponent("Config", isDirectory: true)
            .appendingPathComponent("speech-engine.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: configURL)

        let locator = DebugAssetLocator(
            currentDirectoryURL: root,
            bundleURL: URL(fileURLWithPath: "/tmp/AleVoiceApp.app", isDirectory: true)
        )

        XCTAssertEqual(locator.speechEngineConfigURL(), configURL)
    }

    func test_speechEngineConfigURLFallsBackFromBundleToRepositoryRoot() throws {
        let root = try makeDirectory(named: "bundle-root")
        let configURL = root
            .appendingPathComponent("Config", isDirectory: true)
            .appendingPathComponent("speech-engine.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: configURL)

        let bundleURL = root
            .appendingPathComponent(".build/debug/AleVoiceApp.app", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bundleURL,
            withIntermediateDirectories: true
        )

        let locator = DebugAssetLocator(
            currentDirectoryURL: URL(fileURLWithPath: "/"),
            bundleURL: bundleURL
        )

        XCTAssertEqual(locator.speechEngineConfigURL(), configURL)
    }

    private func makeDirectory(named name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("alevoice-debug-asset-tests-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
