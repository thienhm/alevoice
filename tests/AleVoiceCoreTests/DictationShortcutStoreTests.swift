import XCTest
@testable import AleVoiceCore

final class DictationShortcutStoreTests: XCTestCase {
    func test_saveThenLoadRoundTripsShortcut() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = UserDefaultsDictationShortcutStore(userDefaults: defaults)
        let shortcut = try DictationShortcut(modifiers: [.command], primaryKey: .keyD)

        try store.save(shortcut)

        XCTAssertEqual(store.load(), shortcut)
    }

    func test_loadReturnsNilForCorruptPayload() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.set(Data("bad".utf8), forKey: "dictationShortcut")
        let store = UserDefaultsDictationShortcutStore(userDefaults: defaults)

        XCTAssertNil(store.load())
    }
}
