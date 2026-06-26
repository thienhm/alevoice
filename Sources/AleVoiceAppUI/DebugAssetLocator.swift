import Foundation

public struct DebugAssetLocator {
    private let currentDirectoryURL: URL
    private let bundleURL: URL
    private let fileManager: FileManager

    public init(
        currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true),
        bundleURL: URL = Bundle.main.bundleURL,
        fileManager: FileManager = .default
    ) {
        self.currentDirectoryURL = currentDirectoryURL
        self.bundleURL = bundleURL
        self.fileManager = fileManager
    }

    public func speechEngineConfigURL() -> URL {
        url(for: "Config/speech-engine.json")
    }

    public func englishSampleAudioURL() -> URL {
        url(for: "data/benchmarks/samples/en-001.wav")
    }

    private func url(for relativePath: String) -> URL {
        let currentDirectoryCandidate = currentDirectoryURL.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: currentDirectoryCandidate.path) {
            return currentDirectoryCandidate
        }

        let repositoryCandidate = repositoryRootURL().appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: repositoryCandidate.path) {
            return repositoryCandidate
        }

        return currentDirectoryCandidate
    }

    private func repositoryRootURL() -> URL {
        var cursor = bundleURL.standardizedFileURL
        while cursor.path != "/" {
            if cursor.lastPathComponent == ".build" {
                return cursor.deletingLastPathComponent()
            }
            let packageURL = cursor.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageURL.path) {
                return cursor
            }
            cursor.deleteLastPathComponent()
        }
        return currentDirectoryURL
    }
}
