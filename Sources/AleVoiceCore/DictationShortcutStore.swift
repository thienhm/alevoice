import Foundation

public protocol DictationShortcutStore: Sendable {
    func load() -> DictationShortcut?
    func save(_ shortcut: DictationShortcut) throws
}

public struct UserDefaultsDictationShortcutStore: DictationShortcutStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "dictationShortcut"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    public func load() -> DictationShortcut? {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(DictationShortcut.self, from: data)
    }

    public func save(_ shortcut: DictationShortcut) throws {
        let data = try JSONEncoder().encode(shortcut)
        userDefaults.set(data, forKey: storageKey)
    }
}
