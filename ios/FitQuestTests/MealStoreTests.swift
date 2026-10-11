import XCTest
@testable import FitQuest

final class MealStoreTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    private let today = Day(key: "2026-10-10")
    private let lunch = Meal(
        id: "m1", slot: .lunch, time: "12:30", name: "Chicken, Rice",
        macros: Macros(kcal: 500, protein: 54, carbs: 40, fat: 12), source: .photo
    )
    private let snack = Meal(
        id: "m2", slot: .snack, time: "16:05", name: "Apple",
        macros: Macros(kcal: 95, protein: 0, carbs: 25, fat: 0), source: .text
    )

    override func setUp() {
        suite = "fq-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: Stored shape

    // These are the Firestore field names from the project's data layout, so a rename is a migration.
    func testAStoredMealUsesTheDocumentedFieldNames() throws {
        let fields = StoredMeal(lunch, day: today, accountID: "a").fields
        XCTAssertEqual(fields["day"] as? String, "2026-10-10")
        XCTAssertEqual(fields["slot"] as? String, "lunch")
        XCTAssertEqual(fields["time"] as? String, "12:30")
        XCTAssertEqual(fields["name"] as? String, "Chicken, Rice")
        XCTAssertEqual(fields["kcal"] as? Int, 500)
        XCTAssertEqual(fields["protein"] as? Int, 54)
        XCTAssertEqual(fields["carbs"] as? Int, 40)
        XCTAssertEqual(fields["fat"] as? Int, 12)
        XCTAssertEqual(fields["source"] as? String, "photo")
        XCTAssertEqual(fields["account"] as? String, "a")
    }

    func testAStoredMealComesBackAsTheSameMeal() throws {
        let stored = StoredMeal(snack, day: today, accountID: "a")
        let decoded = try JSONDecoder().decode(StoredMeal.self, from: JSONEncoder().encode(stored))
        XCTAssertEqual(decoded.meal, snack)
        XCTAssertEqual(decoded.dayValue, today)
    }

    // MARK: On the phone

    func testMealsAreKeptPerAccountAndPerDay() async throws {
        let store = LocalMealStore(defaults: defaults)
        try await store.save(lunch, on: today, for: "a")
        try await store.save(snack, on: today, for: "a")
        try await store.save(snack, on: today.adding(-1), for: "b")

        let mine = try await LocalMealStore(defaults: defaults).meals(for: "a")
        XCTAssertEqual(mine, [today: [lunch, snack]], "In the order they were logged, and still there after a relaunch")
        let theirs = try await store.meals(for: "b")
        XCTAssertEqual(theirs, [today.adding(-1): [snack]])
        let nobody = try await store.meals(for: "c")
        XCTAssertTrue(nobody.isEmpty)
    }

    func testSavingTheSameMealAgainReplacesIt() async throws {
        let store = LocalMealStore(defaults: defaults)
        try await store.save(lunch, on: today, for: "a")
        var edited = lunch
        edited.name = "Chicken, Rice, Broccoli"
        try await store.save(edited, on: today, for: "a")
        let meals = try await store.meals(for: "a")
        XCTAssertEqual(meals, [today: [edited]])
    }

    // MARK: Phone plus cloud copy

    func testEveryMealIsSavedOnThePhoneAndCopiedToTheCloud() async throws {
        let local = LocalMealStore(defaults: defaults)
        let cloud = RecordingMealStore()
        let store = MirroredMealStore(local: local, remote: cloud)

        try await store.save(lunch, on: today, for: "a")
        await store.remoteCopies()

        let onPhone = try await local.meals(for: "a")
        XCTAssertEqual(onPhone, [today: [lunch]])
        XCTAssertEqual(cloud.saved, [lunch])
    }

    // Meals logged while the cloud was unreachable (or before it was set up) are sent the next time the app opens.
    func testMealsThatMissedTheCloudAreSentOnTheNextLaunch() async throws {
        let local = LocalMealStore(defaults: defaults)
        try await local.save(lunch, on: today.adding(-1), for: "a")
        try await local.save(snack, on: today, for: "a")
        let cloud = RecordingMealStore()
        let store = MirroredMealStore(local: local, remote: cloud)

        let meals = try await store.meals(for: "a")
        await store.remoteCopies()

        XCTAssertEqual(meals.count, 2)
        XCTAssertEqual(cloud.saved, [lunch, snack], "Oldest day first")

        _ = try await store.meals(for: "a")
        await store.remoteCopies()
        XCTAssertEqual(cloud.saved.count, 2, "Once per launch is enough")
    }

    // The phone's copy is what the app reads, so a cloud that is down or refusing must not lose a meal.
    func testACloudFailureDoesNotLoseTheMeal() async throws {
        let cloud = RecordingMealStore()
        cloud.failing = true
        let store = MirroredMealStore(local: LocalMealStore(defaults: defaults), remote: cloud)

        try await store.save(lunch, on: today, for: "a")
        await store.remoteCopies()

        let meals = try await store.meals(for: "a")
        XCTAssertEqual(meals, [today: [lunch]])
    }
}

final class RecordingMealStore: MealStoring {
    struct Down: Error {}

    var failing = false
    private(set) var saved: [Meal] = []

    func meals(for accountID: String) async throws -> [Day: [Meal]] {
        if failing { throw Down() }
        return [:]
    }

    func save(_ meal: Meal, on day: Day, for accountID: String) async throws {
        if failing { throw Down() }
        saved.append(meal)
    }
}
