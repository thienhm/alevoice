import AleVoiceCore
import CryptoKit
import Foundation

enum SetupInstallerError: Error, Equatable, CustomStringConvertible {
    case unsupportedEngine(String)
    case downloadFailed(String)
    case checksumMismatch(artifact: String, expected: String, actual: String)
    case installFailed(String)
    case doctorFailed(String)

    var description: String {
        switch self {
        case let .unsupportedEngine(message),
             let .downloadFailed(message),
             let .installFailed(message),
             let .doctorFailed(message):
            return message
        case let .checksumMismatch(artifact, expected, actual):
            return "checksum mismatch for \(artifact): expected \(expected), got \(actual)"
        }
    }
}

protocol ArtifactDownloading {
    func download(from url: URL, to destinationURL: URL) throws
}

protocol SHA256Hashing {
    func digest(of fileURL: URL) throws -> String
}

protocol ArchiveExtracting {
    func extract(archiveAt archiveURL: URL, kind: ArtifactUnpackKind, to destinationURL: URL) throws
}

struct SetupDoctorCheck: Equatable {
    enum Status: Equatable {
        case passed
        case failed
    }

    let name: String
    let status: Status
    let detail: String
}

struct SetupDoctorResult: Equatable {
    let checks: [SetupDoctorCheck]

    var isHealthy: Bool {
        checks.allSatisfy { $0.status == .passed }
    }
}

struct SetupInstallRequest {
    let manifest: SetupManifest
    let installRoot: URL
    let configURL: URL
    let platform: SetupPlatform
    let variantName: String?
    let forceDownload: Bool
}

struct SetupInstallResult: Equatable {
    let binaryURL: URL
    let modelURL: URL
    let configURL: URL
    let doctorResult: SetupDoctorResult
}

struct SetupInstaller {
    private let downloader: ArtifactDownloading
    private let hasher: SHA256Hashing
    private let extractor: ArchiveExtracting
    private let doctor: (URL) throws -> SetupDoctorResult
    private let fileManager: FileManager

    init(
        downloader: ArtifactDownloading = URLArtifactDownloader(),
        hasher: SHA256Hashing = FileSHA256Hasher(),
        extractor: ArchiveExtracting = ArchiveToolExtractor(),
        doctor: @escaping (URL) throws -> SetupDoctorResult = { _ in SetupDoctorResult(checks: []) },
        fileManager: FileManager = .default
    ) {
        self.downloader = downloader
        self.hasher = hasher
        self.extractor = extractor
        self.doctor = doctor
        self.fileManager = fileManager
    }

    func install(request: SetupInstallRequest) throws -> SetupInstallResult {
        guard request.manifest.engineKind == SpeechEngineKind.funasr.rawValue else {
            throw SetupInstallerError.unsupportedEngine("unsupported engine kind \(request.manifest.engineKind)")
        }

        let variant = try request.manifest.variant(named: request.variantName)
        let runtime = try variant.runtimeArtifact(for: request.platform)
        let primaryModel = try primaryModel(from: variant)
        let layout = SetupInstallLayout(
            installRoot: request.installRoot,
            engineID: request.manifest.id,
            runtimeBinaryRelativePath: runtime.binaryRelativePath,
            primaryModelRelativePath: primaryModel.relativePath
        )
        try layout.createDirectories(with: fileManager)

        let runtimeDownloadURL = layout.downloadsDirectory.appendingPathComponent(runtime.url.lastPathComponent)
        let modelDownloadURL = layout.downloadsDirectory.appendingPathComponent(primaryModel.url.lastPathComponent)

        try downloadIfNeeded(from: runtime.url, to: runtimeDownloadURL, force: request.forceDownload)
        try verifyChecksum(fileURL: runtimeDownloadURL, expected: runtime.sha256)

        try downloadIfNeeded(from: primaryModel.url, to: modelDownloadURL, force: request.forceDownload)
        try verifyChecksum(fileURL: modelDownloadURL, expected: primaryModel.sha256)

        try resetDirectory(at: layout.runtimeDirectory)
        try extractor.extract(archiveAt: runtimeDownloadURL, kind: runtime.unpack, to: layout.runtimeDirectory)
        try markExecutable(at: layout.binaryURL)

        if fileManager.fileExists(atPath: layout.modelURL.path) {
            try fileManager.removeItem(at: layout.modelURL)
        }
        try fileManager.copyItem(at: modelDownloadURL, to: layout.modelURL)

        let settings = SpeechEngineSettings(
            selectedEngineID: request.manifest.id,
            engines: [
                request.manifest.id: EngineInstallConfig(
                    engineKind: .funasr,
                    binaryPath: layout.binaryURL.path,
                    modelPath: layout.modelURL.path,
                    defaultMode: variant.configTemplate.defaultMode
                ),
            ]
        )
        try fileManager.createDirectory(
            at: request.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try settings.save(to: request.configURL)

        let doctorResult = try doctor(request.configURL)
        guard doctorResult.isHealthy || doctorResult.checks.isEmpty else {
            throw SetupInstallerError.doctorFailed("doctor reported one or more failed checks")
        }

        return SetupInstallResult(
            binaryURL: layout.binaryURL,
            modelURL: layout.modelURL,
            configURL: request.configURL,
            doctorResult: doctorResult
        )
    }

    private func primaryModel(from variant: SetupVariantManifest) throws -> SetupModelArtifact {
        guard let primaryModel = variant.models.first else {
            throw SetupInstallerError.installFailed("variant does not define any model artifacts")
        }
        return primaryModel
    }

    private func downloadIfNeeded(from sourceURL: URL, to destinationURL: URL, force: Bool) throws {
        if fileManager.fileExists(atPath: destinationURL.path), force == false {
            return
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        do {
            try downloader.download(from: sourceURL, to: destinationURL)
        } catch {
            throw SetupInstallerError.downloadFailed("download failed for \(sourceURL.absoluteString): \(error)")
        }
    }

    private func verifyChecksum(fileURL: URL, expected: String) throws {
        let actual = try hasher.digest(of: fileURL)
        guard actual.lowercased() == expected.lowercased() else {
            throw SetupInstallerError.checksumMismatch(
                artifact: fileURL.lastPathComponent,
                expected: expected,
                actual: actual
            )
        }
    }

    private func resetDirectory(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func markExecutable(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw SetupInstallerError.installFailed("runtime binary missing at \(url.path)")
        }
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}

private struct SetupInstallLayout {
    let installRoot: URL
    let downloadsDirectory: URL
    let runtimeDirectory: URL
    let modelsDirectory: URL
    let binaryURL: URL
    let modelURL: URL

    init(
        installRoot: URL,
        engineID: String,
        runtimeBinaryRelativePath: String,
        primaryModelRelativePath: String
    ) {
        let engineRoot = installRoot
            .appendingPathComponent("engines", isDirectory: true)
            .appendingPathComponent(engineID, isDirectory: true)
            .appendingPathComponent("current", isDirectory: true)
        self.installRoot = installRoot
        self.downloadsDirectory = installRoot.appendingPathComponent("downloads", isDirectory: true)
        self.runtimeDirectory = engineRoot.appendingPathComponent("runtime", isDirectory: true)
        self.modelsDirectory = engineRoot.appendingPathComponent("models", isDirectory: true)
        self.binaryURL = runtimeDirectory.appendingPathComponent(runtimeBinaryRelativePath)
        self.modelURL = modelsDirectory.appendingPathComponent(primaryModelRelativePath)
    }

    func createDirectories(with fileManager: FileManager) throws {
        try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
}

private struct URLArtifactDownloader: ArtifactDownloading {
    func download(from url: URL, to destinationURL: URL) throws {
        let semaphore = DispatchSemaphore(value: 0)
        final class State: @unchecked Sendable {
            var temporaryURL: URL?
            var error: Error?
        }
        let state = State()
        let task = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
            if let error {
                state.error = error
            } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                state.error = SetupInstallerError.downloadFailed("\(url.absoluteString) returned HTTP \(http.statusCode)")
            } else {
                state.temporaryURL = temporaryURL
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = state.error {
            throw error
        }
        guard let temporaryURL = state.temporaryURL else {
            throw SetupInstallerError.downloadFailed("download produced no file for \(url.absoluteString)")
        }

        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
    }
}

private struct FileSHA256Hasher: SHA256Hashing {
    func digest(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct ArchiveToolExtractor: ArchiveExtracting {
    func extract(archiveAt archiveURL: URL, kind: ArtifactUnpackKind, to destinationURL: URL) throws {
        switch kind {
        case .direct:
            let outputURL = destinationURL.appendingPathComponent(archiveURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.copyItem(at: archiveURL, to: outputURL)
        case .tarGzip:
            try runProcess(command: ["/usr/bin/tar", "-xzf", archiveURL.path, "-C", destinationURL.path])
        case .zip:
            try runProcess(command: ["/usr/bin/unzip", "-o", archiveURL.path, "-d", destinationURL.path])
        }
    }

    private func runProcess(command: [String]) throws {
        let output = try SystemProcessRunner(timeoutSeconds: 120).run(command: command)
        if output.stderr.isEmpty == false {
            return
        }
    }
}
