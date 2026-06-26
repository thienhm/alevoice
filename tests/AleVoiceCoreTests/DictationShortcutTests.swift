import XCTest
@testable import AleVoiceCore

final class DictationShortcutTests: XCTestCase {
    func test_initRejectsShortcutWithoutModifier() throws {
        XCTAssertThrowsError(
            try DictationShortcut(modifiers: [], primaryKey: .space)
        ) { error in
            XCTAssertEqual(error as? DictationShortcutError, .missingModifier)
        }
    }

    func test_initAcceptsModifierOnlyShortcut() throws {
        let shortcut = try DictationShortcut(modifiers: [.control], primaryKey: nil)

        XCTAssertEqual(shortcut.displayText, "Control")
    }

    func test_initAcceptsModifierAndPrimaryKeyShortcut() throws {
        let shortcut = try DictationShortcut(modifiers: [.control, .shift], primaryKey: .space)

        XCTAssertEqual(shortcut.displayText, "Control+Shift+Space")
    }

    func test_supportedPrimaryKeyRejectsUnknownCodes() {
        XCTAssertNil(DictationShortcut.PrimaryKey(keyCode: 255))
    }

    func test_decodingRejectsShortcutWithoutModifier() throws {
        let data = Data("""
        {
          "modifiers": 0,
          "primaryKey": { "keyCode": 49, "displayName": "Space" }
        }
        """.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(DictationShortcut.self, from: data)) { error in
            XCTAssertEqual(error as? DictationShortcutError, .missingModifier)
        }
    }

    func test_decodingRejectsUnsupportedPrimaryKey() throws {
        let data = Data("""
        {
          "keyCode": 255,
          "displayName": "Unknown"
        }
        """.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(DictationShortcut.PrimaryKey.self, from: data)) { error in
            XCTAssertEqual(error as? DictationShortcutError, .unsupportedPrimaryKey(255))
        }
    }
}
