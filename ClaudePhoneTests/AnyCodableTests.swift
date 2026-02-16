import XCTest
@testable import ClaudePhone

final class AnyCodableTests: XCTestCase {

    // MARK: - Equality Tests

    func testEqualityWithBooleans() {
        let a = AnyCodable(true)
        let b = AnyCodable(true)
        let c = AnyCodable(false)

        XCTAssertEqual(a, b, "Same boolean values should be equal")
        XCTAssertNotEqual(a, c, "Different boolean values should not be equal")
    }

    func testEqualityWithIntegers() {
        let a = AnyCodable(42)
        let b = AnyCodable(42)
        let c = AnyCodable(43)

        XCTAssertEqual(a, b, "Same integer values should be equal")
        XCTAssertNotEqual(a, c, "Different integer values should not be equal")
    }

    func testEqualityWithDoubles() {
        let a = AnyCodable(3.14)
        let b = AnyCodable(3.14)
        let c = AnyCodable(2.71)

        XCTAssertEqual(a, b, "Same double values should be equal")
        XCTAssertNotEqual(a, c, "Different double values should not be equal")
    }

    func testEqualityWithStrings() {
        let a = AnyCodable("hello")
        let b = AnyCodable("hello")
        let c = AnyCodable("world")

        XCTAssertEqual(a, b, "Same string values should be equal")
        XCTAssertNotEqual(a, c, "Different string values should not be equal")
    }

    func testEqualityWithNSNull() {
        let a = AnyCodable(NSNull())
        let b = AnyCodable(NSNull())

        XCTAssertEqual(a, b, "NSNull values should be equal")
    }

    func testEqualityWithArrays() {
        let a = AnyCodable([1, 2, 3])
        let b = AnyCodable([1, 2, 3])
        let c = AnyCodable([1, 2, 4])
        let d = AnyCodable([1, 2])

        XCTAssertEqual(a, b, "Same array values should be equal")
        XCTAssertNotEqual(a, c, "Arrays with different elements should not be equal")
        XCTAssertNotEqual(a, d, "Arrays with different lengths should not be equal")
    }

    func testEqualityWithDictionaries() {
        let a = AnyCodable(["key1": "value1", "key2": 42])
        let b = AnyCodable(["key1": "value1", "key2": 42])
        let c = AnyCodable(["key1": "value1", "key2": 43])
        let d = AnyCodable(["key1": "value1"])

        XCTAssertEqual(a, b, "Same dictionary values should be equal")
        XCTAssertNotEqual(a, c, "Dictionaries with different values should not be equal")
        XCTAssertNotEqual(a, d, "Dictionaries with different keys should not be equal")
    }

    func testEqualityWithDifferentTypes() {
        let intVal = AnyCodable(1)
        let doubleVal = AnyCodable(1.0)
        let stringVal = AnyCodable("1")
        let boolVal = AnyCodable(true)

        // FIXED: These should now correctly be unequal
        XCTAssertNotEqual(intVal, doubleVal, "Int and Double should not be equal even if numerically same")
        XCTAssertNotEqual(intVal, stringVal, "Int and String should not be equal")
        XCTAssertNotEqual(intVal, boolVal, "Int and Bool should not be equal")
    }

    // MARK: - Value Accessor Tests

    func testStringValueAccessor() {
        let stringValue = AnyCodable("test")
        let intValue = AnyCodable(42)

        XCTAssertEqual(stringValue.stringValue, "test")
        XCTAssertNil(intValue.stringValue, "Should return nil for non-string values")
    }

    func testIntValueAccessor() {
        let intValue = AnyCodable(42)
        let stringValue = AnyCodable("test")

        XCTAssertEqual(intValue.intValue, 42)
        XCTAssertNil(stringValue.intValue, "Should return nil for non-int values")
    }

    func testDoubleValueAccessor() {
        let doubleValue = AnyCodable(3.14)
        let stringValue = AnyCodable("test")

        XCTAssertEqual(doubleValue.doubleValue, 3.14)
        XCTAssertNil(stringValue.doubleValue, "Should return nil for non-double values")
    }

    func testBoolValueAccessor() {
        let boolValue = AnyCodable(true)
        let stringValue = AnyCodable("test")

        XCTAssertEqual(boolValue.boolValue, true)
        XCTAssertNil(stringValue.boolValue, "Should return nil for non-bool values")
    }

    func testArrayValueAccessor() {
        let arrayValue = AnyCodable([1, 2, 3])
        let stringValue = AnyCodable("test")

        XCTAssertNotNil(arrayValue.arrayValue)
        XCTAssertEqual(arrayValue.arrayValue?.count, 3)
        XCTAssertNil(stringValue.arrayValue, "Should return nil for non-array values")
    }

    func testDictValueAccessor() {
        let dictValue = AnyCodable(["key": "value"])
        let stringValue = AnyCodable("test")

        XCTAssertNotNil(dictValue.dictValue)
        XCTAssertEqual(dictValue.dictValue?["key"] as? String, "value")
        XCTAssertNil(stringValue.dictValue, "Should return nil for non-dict values")
    }

    // MARK: - Encoding/Decoding Tests

    func testEncodeDecodeString() throws {
        let original = AnyCodable("test string")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testEncodeDecodeInt() throws {
        let original = AnyCodable(42)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testEncodeDecodeDouble() throws {
        let original = AnyCodable(3.14159)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testEncodeDecodeBool() throws {
        let original = AnyCodable(true)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testEncodeDecodeArray() throws {
        let original = AnyCodable([1, "two", true, 3.14])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testEncodeDecodeDictionary() throws {
        let original = AnyCodable([
            "string": "value",
            "number": 42,
            "bool": true,
            "nested": ["a": 1, "b": 2]
        ])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testEncodeDecodeNull() throws {
        let original = AnyCodable(NSNull())
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        XCTAssertEqual(original, decoded)
    }
}
