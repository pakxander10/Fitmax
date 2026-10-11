import XCTest
@testable import FitQuest

/// Signed out → onboarding → ready, as `AppModel` sees it.
final class SessionTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    private let profile = UserProfile(
        sex: .male, age: 24, heightCm: 178, weightKg: 74.5, goal: .leanBulk, experience: .intermediate,
        daysPerWeek: 4, injuries: [], equipment: [.barbell]
    )

    override func setUp() {
        suite = "fq-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func makeModel(profiles: ProfileStoring? = nil) -> AppModel {
        AppModel(
            today: Day(key: "2026-10-10"),
            auth: LocalAuthService(defaults: defaults),
            profiles: profiles ?? LocalProfileStore(defaults: defaults)
        )
    }

    func testANewInstallStartsSignedOut() {
        let model = makeModel()
        XCTAssertEqual(model.stage, .signedOut)
        XCTAssertNil(model.account)
        XCTAssertEqual(model.targets, Targets())
    }

    func testSigningUpLeadsToOnboarding() async throws {
        let model = makeModel()
        try await model.signUp(name: "Alex Moreno", email: "alex@example.com", password: "secret1")
        XCTAssertEqual(model.stage, .onboarding)
        XCTAssertEqual(model.account?.name, "Alex Moreno")
        XCTAssertNil(model.profile)
    }

    func testFinishingOnboardingSavesTheProfileAndSetsTargets() async throws {
        let store = LocalProfileStore(defaults: defaults)
        let model = makeModel(profiles: store)
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")

        try await model.completeOnboarding(profile)

        XCTAssertEqual(model.stage, .ready)
        XCTAssertEqual(model.profile, profile)
        XCTAssertEqual(model.targets, TargetCalculator.targets(for: profile))
        XCTAssertEqual(model.remainingKcal, 2_950, "The ring uses the profile's target, not the default")
        let id = try XCTUnwrap(model.account?.id)
        let saved = try await store.profile(for: id)
        XCTAssertEqual(saved, profile)
    }

    // Sample meals are for previews only: a real account starts with a clean log.
    func testANewAccountHasNoMeals() async throws {
        let model = makeModel()
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try await model.completeOnboarding(profile)

        XCTAssertTrue(model.logs.isEmpty)
        XCTAssertTrue(model.loggedDays.isEmpty)
        XCTAssertEqual(model.consumed, Macros())
        let today = model.today
        for offset in -6...0 {
            XCTAssertFalse(model.status(for: today.adding(offset)).calories, "No meals, so no calorie tick \(offset) days back")
        }
    }

    func testMealsDoNotCarryOverToTheNextAccount() async throws {
        let model = makeModel()
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try await model.completeOnboarding(profile)
        model.saveMeal(slot: .dinner, items: SampleData.photoEstimate, source: .photo)
        XCTAssertEqual(model.consumed.kcal, 500)

        model.signOut()
        try await model.signUp(name: "Sam", email: "sam@example.com", password: "secret1")

        XCTAssertTrue(model.logs.isEmpty)
    }

    func testOnboardingCannotFinishWhileSignedOut() async {
        let model = makeModel()
        do {
            try await model.completeOnboarding(profile)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(model.stage, .signedOut)
            XCTAssertNil(model.profile)
        }
    }

    func testRelaunchRestoresTheSession() async throws {
        let first = makeModel()
        try await first.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try await first.completeOnboarding(profile)

        let relaunched = makeModel()
        XCTAssertEqual(relaunched.stage, .launching, "Known account, profile not loaded yet")
        await relaunched.restoreSession()

        XCTAssertEqual(relaunched.stage, .ready)
        XCTAssertEqual(relaunched.account, first.account)
        XCTAssertEqual(relaunched.profile, profile)
    }

    func testRelaunchMidOnboardingResumesOnboarding() async throws {
        let first = makeModel()
        try await first.signUp(name: "Alex", email: "alex@example.com", password: "secret1")

        let relaunched = makeModel()
        await relaunched.restoreSession()
        XCTAssertEqual(relaunched.stage, .onboarding)
    }

    func testSigningOutReturnsToTheLoginScreen() async throws {
        let model = makeModel()
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try await model.completeOnboarding(profile)
        model.page = .gym
        model.present(.profile)

        model.signOut()

        XCTAssertEqual(model.stage, .signedOut)
        XCTAssertNil(model.account)
        XCTAssertNil(model.profile)
        XCTAssertNil(model.overlay)
        XCTAssertEqual(model.page, .dashboard)
        XCTAssertEqual(model.targets, Targets())
        XCTAssertEqual(makeModel().stage, .signedOut, "Stays signed out after a relaunch")
    }

    func testSigningBackInSkipsOnboarding() async throws {
        let model = makeModel()
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try await model.completeOnboarding(profile)
        model.signOut()

        try await model.signIn(email: "alex@example.com", password: "secret1")

        XCTAssertEqual(model.stage, .ready)
        XCTAssertEqual(model.profile, profile)
    }

    func testAFailedSignInChangesNothing() async throws {
        let model = makeModel()
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        model.signOut()
        do {
            try await model.signIn(email: "alex@example.com", password: "wrong-one")
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? AuthError, .wrongCredentials)
        }
        XCTAssertEqual(model.stage, .signedOut)
    }

    // A profile that fails to load must never look like "no profile yet": onboarding again would overwrite it.
    func testAProfileThatFailsToLoadDoesNotRestartOnboarding() async throws {
        let first = makeModel()
        try await first.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try await first.completeOnboarding(profile)

        let store = FlakyProfileStore(wrapping: LocalProfileStore(defaults: defaults))
        store.failing = true
        let relaunched = makeModel(profiles: store)
        await relaunched.restoreSession()
        XCTAssertEqual(relaunched.stage, .launching)
        XCTAssertTrue(relaunched.restoreFailed)

        store.failing = false
        await relaunched.restoreSession()
        XCTAssertEqual(relaunched.stage, .ready)
        XCTAssertFalse(relaunched.restoreFailed)
    }

    func testOnlyTheOnDeviceStandInCountsAsLocalAccounts() {
        XCTAssertTrue(makeModel().usesLocalAccounts)
    }
}

private final class FlakyProfileStore: ProfileStoring {
    struct Offline: Error {}

    let wrapped: ProfileStoring
    var failing = false

    init(wrapping wrapped: ProfileStoring) { self.wrapped = wrapped }

    func profile(for accountID: String) async throws -> UserProfile? {
        if failing { throw Offline() }
        return try await wrapped.profile(for: accountID)
    }

    func save(_ profile: UserProfile, for accountID: String) async throws {
        if failing { throw Offline() }
        try await wrapped.save(profile, for: accountID)
    }
}
