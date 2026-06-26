import Foundation

public enum DictationShortcutError: Error, Equatable, LocalizedError, Sendable {
    case missingModifier
    case unsupportedPrimaryKey(UInt16)

    public var errorDescription: String? {
        switch self {
        case .missingModifier:
            return "Shortcut must include at least one modifier"
        case .unsupportedPrimaryKey(let keyCode):
            return "Shortcut key code \(keyCode) is not supported"
        }
    }
}

public struct DictationShortcut: Codable, Equatable, Sendable {
    public struct ModifierSet: OptionSet, Codable, Equatable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let command = ModifierSet(rawValue: 1 << 0)
        public static let shift = ModifierSet(rawValue: 1 << 1)
        public static let option = ModifierSet(rawValue: 1 << 2)
        public static let control = ModifierSet(rawValue: 1 << 3)
        public static let function = ModifierSet(rawValue: 1 << 4)
    }

    public struct PrimaryKey: Codable, Equatable, Sendable {
        public let keyCode: UInt16
        public let displayName: String

        public init?(keyCode: UInt16) {
            guard let displayName = Self.supportedKeys[keyCode] else {
                return nil
            }
            self.keyCode = keyCode
            self.displayName = displayName
        }

        public static let space = PrimaryKey(keyCode: 49)!
        public static let keyD = PrimaryKey(keyCode: 2)!

        private static let supportedKeys: [UInt16: String] = [
            49: "Space",
            0: "A",
            1: "S",
            2: "D",
            13: "W"
        ]
    }

    public let modifiers: ModifierSet
    public let primaryKey: PrimaryKey?

    public init(modifiers: ModifierSet, primaryKey: PrimaryKey?) throws {
        guard !modifiers.isEmpty else {
            throw DictationShortcutError.missingModifier
        }
        self.modifiers = modifiers
        self.primaryKey = primaryKey
    }

    public var displayText: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Command") }
        if modifiers.contains(.function) { parts.append("Fn") }
        if let primaryKey {
            parts.append(primaryKey.displayName)
        }
        return parts.joined(separator: "+")
    }
}
