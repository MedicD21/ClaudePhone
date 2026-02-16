import XCTest
@testable import ClaudePhone

final class KeychainManagerTests: XCTestCase {

    let keychain = KeychainManager.shared

    override func setUp() async throws {
        try await super.setUp()
        // Clean up before each test
        try? keychain.deleteAPIKey()
    }

    override func tearDown() async throws {
        // Clean up after each test
        try? keychain.deleteAPIKey()
        try await super.tearDown()
    }

    // MARK: - Validation Tests

    func testValidateValidAPIKey() {
        let validKey = "sk-ant-abcdefghijklmnopqrstuvwxyz1234567890"
        XCTAssertTrue(keychain.validateAPIKey(validKey), "Should validate correct API key format")
    }

    func testValidateInvalidPrefix() {
        let invalidKey = "invalid-ant-abcdefghijklmnopqrstuvwxyz1234567890"
        XCTAssertFalse(keychain.validateAPIKey(invalidKey), "Should reject incorrect prefix")
    }

    func testValidateTooShort() {
        let shortKey = "sk-ant-short"
        XCTAssertFalse(keychain.validateAPIKey(shortKey), "Should reject too-short keys")
    }

    func testValidateWithInvalidCharacters() {
        let invalidKey = "sk-ant-abc@#$%^&*()123456789012345"
        XCTAssertFalse(keychain.validateAPIKey(invalidKey), "Should reject keys with invalid characters")
    }

    func testValidateWithWhitespace() {
        let keyWithSpaces = "sk-ant-abc def ghijklmnopqrstuvwxyz"
        XCTAssertFalse(keychain.validateAPIKey(keyWithSpaces), "Should reject keys with whitespace")
    }

    // MARK: - Save/Load Tests

    func testSaveAndRetrieveAPIKey() throws {
        let testKey = "sk-ant-test1234567890abcdefghijklmnop"

        try keychain.saveAPIKey(testKey)

        let retrieved = keychain.getAPIKey()
        XCTAssertEqual(retrieved, testKey, "Should retrieve the same key that was saved")
    }

    func testSaveInvalidKeyThrowsError() {
        let invalidKey = "invalid-key"

        XCTAssertThrowsError(try keychain.saveAPIKey(invalidKey)) { error in
            XCTAssertTrue(error is KeychainError, "Should throw KeychainError")
            if let keychainError = error as? KeychainError {
                switch keychainError {
                case .invalidKeyFormat:
                    break // Expected error
                default:
                    XCTFail("Should throw invalidKeyFormat error")
                }
            }
        }
    }

    func testSaveTrimsWhitespace() throws {
        let keyWithWhitespace = "  sk-ant-test1234567890abcdefghijklmnop  "
        let expectedKey = "sk-ant-test1234567890abcdefghijklmnop"

        try keychain.saveAPIKey(keyWithWhitespace)

        let retrieved = keychain.getAPIKey()
        XCTAssertEqual(retrieved, expectedKey, "Should trim whitespace before saving")
    }

    func testOverwriteExistingKey() throws {
        let firstKey = "sk-ant-first1234567890abcdefghijklmno"
        let secondKey = "sk-ant-second123456789abcdefghijklmn"

        try keychain.saveAPIKey(firstKey)
        try keychain.saveAPIKey(secondKey)

        let retrieved = keychain.getAPIKey()
        XCTAssertEqual(retrieved, secondKey, "Should overwrite previous key")
    }

    // MARK: - Delete Tests

    func testDeleteAPIKey() throws {
        let testKey = "sk-ant-test1234567890abcdefghijklmnop"
        try keychain.saveAPIKey(testKey)

        try keychain.deleteAPIKey()

        XCTAssertNil(keychain.getAPIKey(), "Should return nil after deletion")
        XCTAssertFalse(keychain.hasAPIKey, "hasAPIKey should be false after deletion")
    }

    func testDeleteNonExistentKey() {
        XCTAssertNoThrow(try keychain.deleteAPIKey(), "Should not throw when deleting non-existent key")
    }

    // MARK: - HasAPIKey Tests

    func testHasAPIKeyWhenPresent() throws {
        let testKey = "sk-ant-test1234567890abcdefghijklmnop"
        try keychain.saveAPIKey(testKey)

        XCTAssertTrue(keychain.hasAPIKey, "Should return true when key is present")
    }

    func testHasAPIKeyWhenAbsent() {
        XCTAssertFalse(keychain.hasAPIKey, "Should return false when no key is saved")
    }
}
