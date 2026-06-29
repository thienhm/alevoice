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
            bundleURL: URL(fileURLWithPath: "/tmp/AleVoice.app", isDirectory: true)
        )

        XCTAssertEqual(locator.speechEngineConfigURL(), configURL)
    }

    func test_speechEngineConfigURLFallsBackFromVisibleBuildBundleToRepositoryRoot() throws {
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
            .appendingPathComponent("build/AleVoice.app", isDirectory: true)
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

    func test_speechEngineConfigURLPrefersRepositoryRootOverBundledResourceForDeveloperBuild() throws {
        let root = try makeDirectory(named: "developer-build-root")
        let configURL = root
            .appendingPathComponent("Config", isDirectory: true)
            .appendingPathComponent("speech-engine.json")
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("repo".utf8).write(to: configURL)

        let bundleURL = root
            .appendingPathComponent(".build/debug/AleVoiceApp.app", isDirectory: true)
        let bundledConfigURL = bundleURL
            .appendingPathComponent("Contents/Resources/Config", isDirectory: true)
            .appendingPathComponent("speech-engine.json")
        try FileManager.default.createDirectory(
            at: bundledConfigURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("bundled".utf8).write(to: bundledConfigURL)

        let locator = DebugAssetLocator(
            currentDirectoryURL: URL(fileURLWithPath: "/", isDirectory: true),
            bundleURL: bundleURL
        )

        XCTAssertEqual(locator.speechEngineConfigURL(), configURL)
    }

    func test_speechEngineConfigURLPrefersBundledResourceWhenInstalledOutsideRepository() throws {
        let appURL = try makeDirectory(named: "installed-app")
            .appendingPathComponent("AleVoice.app", isDirectory: true)
        let resourceConfigURL = appURL
            .appendingPathComponent("Contents/Resources/Config", isDirectory: true)
            .appendingPathComponent("speech-engine.json")
        try FileManager.default.createDirectory(
            at: resourceConfigURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: resourceConfigURL)

        let locator = DebugAssetLocator(
            currentDirectoryURL: URL(fileURLWithPath: "/", isDirectory: true),
            bundleURL: appURL
        )

        XCTAssertEqual(locator.speechEngineConfigURL(), resourceConfigURL)
    }

    private func makeDirectory(named name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("alevoice-debug-asset-tests-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
