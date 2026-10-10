import XCTest
@testable import FitQuest

final class GeminiFoodAnalyzerTests: XCTestCase {
    private func envelope(_ json: String) -> Data {
        let wrapper: [String: Any] = ["candidates": [["content": ["parts": [["text": json]]]]]]
        return try! JSONSerialization.data(withJSONObject: wrapper)
    }

    func testParsesItems() throws {
        let items = try GeminiFoodAnalyzer.parse(envelope(
            #"{"items":[{"name":"Rice","grams":180,"kcal":202,"protein":5,"carbs":42,"fat":2,"confidence":"High"}]}"#))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Rice")
        XCTAssertEqual(items[0].macros, Macros(kcal: 202, protein: 5, carbs: 42, fat: 2))
        XCTAssertEqual(items[0].confidence, .high)
    }

    func testEmptyListMeansNoFood() throws {
        XCTAssertTrue(try GeminiFoodAnalyzer.parse(envelope(#"{"items":[]}"#)).isEmpty)
    }

    func testMissingContentThrows() {
        XCTAssertThrowsError(try GeminiFoodAnalyzer.parse(Data(#"{"candidates":[]}"#.utf8)))
    }
}
