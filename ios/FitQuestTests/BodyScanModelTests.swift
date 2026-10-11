import XCTest
@testable import FitQuest

@MainActor
final class BodyScanModelTests: XCTestCase {
    private final class FakeScanner: BodyScanning {
        var result: Result<Biometrics, ScanError>
        private(set) var requests: [ScanRequest] = []

        init(_ result: Result<Biometrics, ScanError>) { self.result = result }

        func scan(_ request: ScanRequest) async throws -> Biometrics {
            requests.append(request)
            return try result.get()
        }
    }

    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "scan-tests-\(UUID().uuidString)")
    }

    private func makeModel() -> AppModel {
        AppModel(
            auth: LocalAuthService(defaults: defaults),
            profiles: LocalProfileStore(defaults: defaults),
            biometricsStore: LocalBiometricsStore(defaults: defaults)
        )
    }

    private func signedInModel() async throws -> AppModel {
        let model = makeModel()
        try await model.signUp(name: "Ada Test", email: "ada@example.com", password: "secret1")
        try await model.completeOnboarding(SampleData.profile)
        return model
    }

    func testScanSendsHeightWeightAndSexFromTheProfile() async throws {
        let model = try await signedInModel()
        let scanner = FakeScanner(.success(BiometricsTests.sample))
        model.bodyScanner = scanner

        _ = try await model.scanBody(Data([1, 2, 3]))

        let sent = try XCTUnwrap(scanner.requests.first)
        XCTAssertEqual(sent.heightCm, SampleData.profile.heightCm)
        XCTAssertEqual(sent.weightKg, SampleData.profile.weightKg)
        XCTAssertEqual(sent.sex, SampleData.profile.sex)
        XCTAssertEqual(sent.photo, Data([1, 2, 3]))
    }

    func testWithoutAScanServerTheScanSaysSo() async throws {
        let model = try await signedInModel()
        model.bodyScanner = nil
        do {
            _ = try await model.scanBody(Data([1]))
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? ScanError, .notConfigured)
        }
    }

    func testSavedScanShowsOnTheProfileAndSurvivesARestart() async throws {
        let model = try await signedInModel()
        model.present(.profile)
        model.present(.bodyScan)

        try await model.saveBiometrics(BiometricsTests.sample)

        XCTAssertEqual(model.biometrics, BiometricsTests.sample)
        XCTAssertEqual(model.overlay, .profile, "saving closes the scan and returns to the profile")
        let reopened = makeModel()
        await reopened.loadBiometrics()
        XCTAssertEqual(reopened.biometrics, BiometricsTests.sample)
    }

    func testSigningOutForgetsTheScan() async throws {
        let model = try await signedInModel()
        try await model.saveBiometrics(BiometricsTests.sample)
        model.signOut()
        XCTAssertNil(model.biometrics)
    }
}
