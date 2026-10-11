import XCTest
@testable import FitQuest

final class BiometricsTests: XCTestCase {
    /// What the scan worker sends back, as in backend/worker/server.py.
    static let workerJSON = #"""
    {"method":"sam3d","confidence":"low","height_cm":175.0,"weight_kg":null,"sex":"male",
     "neck_cm":38.0,"chest_cm":99.5,"waist_cm":84.0,"hips_cm":97.0,"body_fat_pct":17.8,
     "body_fat_method":"navy","measured_at":"2026-10-11T02:29:13Z","user_edited_fields":[]}
    """#

    static var sample: Biometrics {
        try! Biometrics.decoder().decode(Biometrics.self, from: Data(workerJSON.utf8))
    }

    func testDecodesTheWorkersReply() throws {
        let scan = try Biometrics.decoder().decode(Biometrics.self, from: Data(Self.workerJSON.utf8))
        XCTAssertEqual(scan.method, .sam3d)
        XCTAssertEqual(scan.confidence, .low)
        XCTAssertEqual(scan.sex, .male)
        XCTAssertEqual(scan.waistCm, 84.0)
        XCTAssertNil(scan.weightKg)
        XCTAssertEqual(scan.bodyFatPct, 17.8)
        XCTAssertEqual(scan.measuredAt, ISO8601DateFormatter().date(from: "2026-10-11T02:29:13Z"))
    }

    func testMissingMeasurementsDecodeAsNil() throws {
        let json = Self.workerJSON.replacingOccurrences(of: #""hips_cm":97.0"#, with: #""hips_cm":null"#)
        XCTAssertNil(try Biometrics.decoder().decode(Biometrics.self, from: Data(json.utf8)).hipsCm)
    }

    func testCorrectingAMeasurementRecomputesBodyFat() {
        let scan = Self.sample
        let edited = scan.editing(.waist, cm: 90)

        XCTAssertEqual(edited.waistCm, 90)
        XCTAssertEqual(edited.userEditedFields, ["waist_cm"])
        XCTAssertEqual(edited.bodyFatPct, Navy.bodyFat(sex: .male, heightCm: 175, neckCm: 38, waistCm: 90, hipsCm: 97))
        XCTAssertEqual(scan.waistCm, 84, "the original scan is left alone")
        XCTAssertEqual(edited.editing(.waist, cm: 91).userEditedFields, ["waist_cm"], "a field is listed once")
    }

    func testSurvivesStorage() throws {
        let edited = Self.sample.editing(.neck, cm: 39)
        let stored = try Biometrics.encoder().encode(edited)
        XCTAssertEqual(try Biometrics.decoder().decode(Biometrics.self, from: stored), edited)
    }
}
