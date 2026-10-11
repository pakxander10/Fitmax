import XCTest
@testable import FitQuest

/// XP, workout history and friends: a new account starts from nothing and keeps what it earns.
final class ProgressTests: XCTestCase {
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

    private func makeModel(today: String = "2026-10-10") -> AppModel {
        AppModel(
            today: Day(key: today),
            auth: LocalAuthService(defaults: defaults), profiles: LocalProfileStore(defaults: defaults),
            mealStore: LocalMealStore(defaults: defaults), progressStore: LocalProgressStore(defaults: defaults)
        )
    }

    private func signedUp(today: String = "2026-10-10") async throws -> AppModel {
        let model = makeModel(today: today)
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try await model.completeOnboarding(profile)
        return model
    }

    // MARK: Streak

    func testStreakCountsUnbrokenDaysEndingToday() {
        let today = Day(key: "2026-10-10")
        XCTAssertEqual(GameState.streak(activeDays: [], today: today), 0)
        XCTAssertEqual(GameState.streak(activeDays: [today], today: today), 1)
        XCTAssertEqual(GameState.streak(activeDays: [today, today.adding(-1), today.adding(-2)], today: today), 3)
        XCTAssertEqual(GameState.streak(activeDays: [today, today.adding(-2)], today: today), 1, "A gap ends it")
    }

    // Today is not over, so not having logged yet must not wipe a streak that ran through yesterday.
    func testStreakSurvivesUntilTheDayIsOver() {
        let today = Day(key: "2026-10-10")
        XCTAssertEqual(GameState.streak(activeDays: [today.adding(-1), today.adding(-2)], today: today), 2)
        XCTAssertEqual(GameState.streak(activeDays: [today.adding(-2)], today: today), 0)
    }

    // MARK: A new account starts from nothing

    func testANewAccountStartsFromZero() async throws {
        let model = try await signedUp()
        XCTAssertEqual(model.xp, 0)
        XCTAssertEqual(model.game.level, 0)
        XCTAssertEqual(model.game.streakDays, 0)
        XCTAssertEqual(model.points, 0)
        for template in model.templates {
            XCTAssertTrue(model.sessions(for: template.id).isEmpty, template.name)
        }
        for gym in SampleData.gyms {
            XCTAssertTrue(model.friends(at: gym.id).isEmpty, gym.name)
        }
        let today = model.today
        for offset in -6...0 {
            XCTAssertEqual(model.status(for: today.adding(offset)), DayStatus(), "\(offset) days back")
        }
        let bench = try XCTUnwrap(model.activeTemplate?.exercises.first)
        XCTAssertEqual(model.lastRecord(for: bench), "–")
    }

    func testTheSampleModelStillHasItsHistory() {
        let model = AppModel(today: Day(key: "2026-10-10"), sampleData: true)
        XCTAssertEqual(model.xp, SampleData.startingXP)
        XCTAssertEqual(model.game.streakDays, SampleData.streakDays)
        XCTAssertFalse(model.friends(at: "ram").isEmpty)
        XCTAssertFalse(model.sessions(for: "push").isEmpty)
    }

    // MARK: Earning and keeping

    func testXPIsEarnedFromZeroAndKept() async throws {
        let first = try await signedUp()
        first.saveMeal(slot: .lunch, items: SampleData.photoEstimate, source: .photo)
        XCTAssertEqual(first.xp, 10)
        XCTAssertEqual(first.game.streakDays, 1)
        await first.pendingSave?.value

        let relaunched = makeModel()
        await relaunched.restoreSession()
        XCTAssertEqual(relaunched.xp, 10)
        XCTAssertEqual(relaunched.game.streakDays, 1)
    }

    func testAFinishedWorkoutIsKeptWithItsRecords() async throws {
        let first = try await signedUp()
        let template = try XCTUnwrap(first.activeTemplate)
        let bench = try XCTUnwrap(template.exercises.first)
        first.setEntry(0, of: bench) { $0.lbs = "185" }
        first.toggleSet(0, of: bench)
        for exercise in template.exercises { _ = first.toggleExerciseDone(exercise.id) }
        first.completeWorkout()
        XCTAssertEqual(first.xp, 100)
        await first.pendingSave?.value

        let relaunched = makeModel()
        await relaunched.restoreSession()

        XCTAssertEqual(relaunched.xp, 100)
        XCTAssertEqual(relaunched.sessions(for: template.id).count, 1)
        XCTAssertTrue(relaunched.status(for: relaunched.today).workout || relaunched.sessions(for: template.id).first?.day == relaunched.today)
        XCTAssertEqual(relaunched.lastRecord(for: bench), "185 × \(bench.reps.upperBound)")
        XCTAssertEqual(relaunched.game.streakDays, 1)
    }

    func testFriendsAreKept() async throws {
        let first = try await signedUp()
        let stranger = try XCTUnwrap(SampleData.members.first { !$0.isPrivate })
        first.addFriend(stranger)
        XCTAssertTrue(first.isFriend(stranger))
        await first.pendingSave?.value

        let relaunched = makeModel()
        await relaunched.restoreSession()
        XCTAssertTrue(relaunched.isFriend(stranger))
    }

    func testProgressBelongsToTheAccount() async throws {
        let model = try await signedUp()
        model.saveMeal(slot: .lunch, items: SampleData.photoEstimate, source: .photo)
        await model.pendingSave?.value
        model.signOut()
        XCTAssertEqual(model.xp, 0)

        try await model.signUp(name: "Sam", email: "sam@example.com", password: "secret1")
        XCTAssertEqual(model.xp, 0)
        model.signOut()

        try await model.signIn(email: "alex@example.com", password: "secret1")
        XCTAssertEqual(model.xp, 10)
    }

    // MARK: Pet name

    func testThePetIsNamedInOnboardingAndCanBeRenamed() async throws {
        let model = makeModel()
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        XCTAssertEqual(model.petName, "Biscuit", "Until it has a name")

        var named = profile
        named.petName = "Rex"
        try await model.completeOnboarding(named)
        XCTAssertEqual(model.petName, "Rex")

        named.petName = "Mochi"
        try await model.completeOnboarding(named)
        let relaunched = makeModel()
        await relaunched.restoreSession()
        XCTAssertEqual(relaunched.petName, "Mochi")
    }
}
