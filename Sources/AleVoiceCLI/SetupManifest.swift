import AleVoiceCore
import Foundation

enum SetupManifestError: Error, Equatable, CustomStringConvertible {
    case invalidManifest(String)
    case unsupportedPlatform(String)
    case unknownVariant(String)

    var description: String {
        switch self {
        case let .invalidManifest(message),
             let .unsupportedPlatform(message),
             let .unknownVariant(message):
            return message
        }
    }
}

enum SetupPlatform: String, Codable, CaseIterable, Sendable {
    case macOSArm64 = "macos-arm64"

    static func current() throws -> SetupPlatform {
        #if arch(arm64)
        return .macOSArm64
        #else
        throw SetupManifestError.unsupportedPlatform("current platform is not supported by the pinned setup manifests")
        #endif
    }
}

enum ArtifactUnpackKind: String, Codable, Equatable, Sendable {
    case direct
    case tarGzip = "tar.gz"
    case zip
}

struct SetupArtifactDownload: Codable, Equatable, Sendable {
    let url: URL
    let sha256: String
}

struct SetupRuntimeArtifact: Codable, Equatable, Sendable {
    let platforms: [SetupPlatform: SetupArtifactDownload]
    let unpack: ArtifactUnpackKind
    let binaryRelativePath: String

    init(
        platforms: [SetupPlatform: SetupArtifactDownload],
        unpack: ArtifactUnpackKind,
        binaryRelativePath: String
    ) {
        self.platforms = platforms
        self.unpack = unpack
        self.binaryRelativePath = binaryRelativePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawPlatforms = try container.decode([String: SetupArtifactDownload].self, forKey: .platforms)
        var platforms: [SetupPlatform: SetupArtifactDownload] = [:]
        for (rawPlatform, artifact) in rawPlatforms {
            guard let platform = SetupPlatform(rawValue: rawPlatform) else {
                throw SetupManifestError.unsupportedPlatform("manifest contains unsupported platform \(rawPlatform)")
            }
            platforms[platform] = artifact
        }
        self.platforms = platforms
        self.unpack = try container.decode(ArtifactUnpackKind.self, forKey: .unpack)
        self.binaryRelativePath = try container.decode(String.self, forKey: .binaryRelativePath)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawPlatforms = Dictionary(uniqueKeysWithValues: platforms.map { ($0.key.rawValue, $0.value) })
        try container.encode(rawPlatforms, forKey: .platforms)
        try container.encode(unpack, forKey: .unpack)
        try container.encode(binaryRelativePath, forKey: .binaryRelativePath)
    }

    func artifact(for platform: SetupPlatform) throws -> SetupResolvedRuntimeArtifact {
        guard let artifact = platforms[platform] else {
            throw SetupManifestError.unsupportedPlatform("manifest does not support platform \(platform.rawValue)")
        }
        return SetupResolvedRuntimeArtifact(
            url: artifact.url,
            sha256: artifact.sha256,
            unpack: unpack,
            binaryRelativePath: binaryRelativePath
        )
    }

    func validate() throws {
        for (platform, artifact) in platforms {
            guard !artifact.sha256.isEmpty else {
                throw SetupManifestError.invalidManifest("runtime \(platform.rawValue) sha256 must be non-empty")
            }
        }
        guard !binaryRelativePath.isEmpty else {
            throw SetupManifestError.invalidManifest("runtime binaryRelativePath must be non-empty")
        }
    }

    private enum CodingKeys: String, CodingKey {
        case platforms
        case unpack
        case binaryRelativePath
    }
}

struct SetupResolvedRuntimeArtifact: Equatable, Sendable {
    let url: URL
    let sha256: String
    let unpack: ArtifactUnpackKind
    let binaryRelativePath: String
}

struct SetupModelArtifact: Codable, Equatable, Sendable {
    let id: String
    let url: URL
    let sha256: String
    let relativePath: String

    func validate() throws {
        guard !sha256.isEmpty else {
            throw SetupManifestError.invalidManifest("model \(id) sha256 must be non-empty")
        }
        guard !relativePath.isEmpty else {
            throw SetupManifestError.invalidManifest("model \(id) relativePath must be non-empty")
        }
    }
}

struct SetupConfigTemplate: Codable, Equatable, Sendable {
    let defaultMode: SpeechLanguageMode
}

struct SetupVariantManifest: Codable, Equatable, Sendable {
    let runtime: SetupRuntimeArtifact
    let models: [SetupModelArtifact]
    let configTemplate: SetupConfigTemplate

    func runtimeArtifact(for platform: SetupPlatform) throws -> SetupResolvedRuntimeArtifact {
        try runtime.artifact(for: platform)
    }

    func validate() throws {
        try runtime.validate()
        guard !models.isEmpty else {
            throw SetupManifestError.invalidManifest("variant must include at least one model")
        }
        for model in models {
            try model.validate()
        }
    }
}

struct SetupManifest: Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let description: String
    let engineKind: String
    let defaultVariant: String
    let variants: [String: SetupVariantManifest]

    static func load(from url: URL) throws -> SetupManifest {
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(Self.self, from: data)
        try manifest.validate()
        return manifest
    }

    func variant(named name: String?) throws -> SetupVariantManifest {
        let resolvedName = name ?? defaultVariant
        guard let variant = variants[resolvedName] else {
            throw SetupManifestError.unknownVariant("manifest does not define variant \(resolvedName)")
        }
        return variant
    }

    private func validate() throws {
        guard !id.isEmpty else {
            throw SetupManifestError.invalidManifest("id must be non-empty")
        }
        guard !displayName.isEmpty else {
            throw SetupManifestError.invalidManifest("displayName must be non-empty")
        }
        guard !engineKind.isEmpty else {
            throw SetupManifestError.invalidManifest("engineKind must be non-empty")
        }
        guard variants[defaultVariant] != nil else {
            throw SetupManifestError.invalidManifest("defaultVariant \(defaultVariant) must exist")
        }
        for variant in variants.values {
            try variant.validate()
        }
    }
}
