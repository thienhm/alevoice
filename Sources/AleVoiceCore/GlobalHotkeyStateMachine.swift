import Foundation

public struct GlobalKeyEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case keyDown
        case keyUp
        case flagsChanged
    }

    public let kind: Kind
    public let keyCode: UInt16?
    public let modifiers: DictationShortcut.ModifierSet

    public init(kind: Kind, keyCode: UInt16?, modifiers: DictationShortcut.ModifierSet) {
        self.kind = kind
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum GlobalHotkeyTransition: Equatable, Sendable {
    case activated
    case released
}

public struct GlobalHotkeyStateMachine: Sendable {
    private let shortcut: DictationShortcut
    private var pressedPrimaryKeyCode: UInt16?
    private var wasActive = false

    public init(shortcut: DictationShortcut) {
        self.shortcut = shortcut
    }

    public mutating func handle(_ event: GlobalKeyEvent) -> [GlobalHotkeyTransition] {
        switch event.kind {
        case .keyDown:
            pressedPrimaryKeyCode = event.keyCode
        case .keyUp:
            if pressedPrimaryKeyCode == event.keyCode {
                pressedPrimaryKeyCode = nil
            }
        case .flagsChanged:
            break
        }

        let modifiersMatch = event.modifiers.isSuperset(of: shortcut.modifiers)
        let primaryMatches = shortcut.primaryKey.map { $0.keyCode == pressedPrimaryKeyCode } ?? true
        let isActive = modifiersMatch && primaryMatches

        defer { wasActive = isActive }

        if isActive && !wasActive {
            return [.activated]
        }
        if !isActive && wasActive {
            return [.released]
        }
        return []
    }
}
