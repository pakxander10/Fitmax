import XCTest
@testable import FitQuest

final class NavyTests: XCTestCase {
    func testMaleKnownValues() throws {
        // 70 in tall, 15 in neck, 34 in waist: 17.5 % with the inch-based formula.
        let pct = try XCTUnwrap(Navy.bodyFat(sex: .male, heightCm: 177.8, neckCm: 38.1, waistCm: 86.36, hipsCm: nil))
        XCTAssertEqual(pct, 17.5, accuracy: 0.1)
    }

    func testFemaleKnownValues() throws {
        // 65 in tall, 13 in neck, 30 in waist, 40 in hips: 31.1 %.
        let pct = try XCTUnwrap(Navy.bodyFat(sex: .female, heightCm: 165.1, neckCm: 33.02, waistCm: 76.2, hipsCm: 101.6))
        XCTAssertEqual(pct, 31.1, accuracy: 0.1)
    }

    func testFemaleEstimateNeedsHips() {
        XCTAssertNil(Navy.bodyFat(sex: .female, heightCm: 165.1, neckCm: 33.02, waistCm: 76.2, hipsCm: nil))
    }

    func testMissingOrImpossibleInputsGiveNoEstimate() {
        XCTAssertNil(Navy.bodyFat(sex: .male, heightCm: 177.8, neckCm: nil, waistCm: 86.36, hipsCm: nil))
        XCTAssertNil(Navy.bodyFat(sex: .male, heightCm: 177.8, neckCm: 90, waistCm: 86.36, hipsCm: nil))
    }
}
