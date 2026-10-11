import XCTest
@testable import FitQuest

/// Meal ideas as `AppModel` hands them to the Calorie page.
final class RecommendationTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!
    private let recommender = ScriptedRecommender()

    override func setUp() {
        suite = "fq-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private func meal(_ name: String, _ kcal: Int) -> MealRecommendation {
        MealRecommendation(name: name, kcal: kcal, protein: 30, link: nil)
    }

    /// Signed in as a vegetarian on a cut: 2,200 kcal and 164 g protein a day. It is 6 pm.
    private func makeModel() async throws -> AppModel {
        let model = AppModel(
            today: Day(key: "2026-10-10"),
            auth: LocalAuthService(defaults: defaults), profiles: LocalProfileStore(defaults: defaults),
            mealStore: LocalMealStore(defaults: defaults)
        )
        model.mealRecommender = recommender
        model.now = { Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 18))! }
        try await model.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try await model.completeOnboarding(UserProfile(
            sex: .male, age: 24, heightCm: 178, weightKg: 74.5, goal: .cut, experience: .intermediate,
            daysPerWeek: 4, injuries: [], equipment: [], diet: [.vegetarian]
        ))
        return model
    }

    func testRequestComesFromTheBudgetTheClockAndTheProfile() async throws {
        let model = try await makeModel()
        XCTAssertEqual(model.mealRequest, MealRequest(budget: 880, remainingProtein: 164, slot: .dinner, goal: .cut, diet: [.vegetarian]))

        model.saveMeal(slot: .lunch, items: SampleData.photoEstimate, source: .photo) // 500 kcal, 54 g protein
        XCTAssertEqual(model.mealRequest?.budget, 880)
        XCTAssertEqual(model.mealRequest?.remainingProtein, 110)
    }

    func testIdeasLoad() async throws {
        let model = try await makeModel()
        XCTAssertEqual(model.recommendations, .idle)
        recommender.meals = [meal("Paneer wrap", 620), meal("Bean chili", 450)]

        await model.refreshRecommendations()

        XCTAssertEqual(model.recommendations, .loaded([meal("Paneer wrap", 620), meal("Bean chili", 450)]))
        XCTAssertEqual(recommender.requests, [model.mealRequest])
    }

    // The model proposes; the budget check is done here in code.
    func testIdeasOverBudgetRepeatsAndExtrasAreDropped() async throws {
        let model = try await makeModel()
        recommender.meals = [
            meal("Feast", 881), meal("Paneer wrap", 880), meal("paneer wrap", 600), meal("Bean chili", 450),
            meal("Dal", 400), meal("Shakshuka", 380), meal("Veggie burger", 520),
        ]

        await model.refreshRecommendations()

        XCTAssertEqual(model.recommendations, .loaded([meal("Paneer wrap", 880), meal("Bean chili", 450), meal("Dal", 400), meal("Shakshuka", 380)]))
    }

    func testIdeasWhoseNamesBreakTheDietAreDropped() async throws {
        let model = try await makeModel() // vegetarian
        recommender.meals = [meal("Chicken burrito bowl", 500), meal("Bean burrito bowl", 480)]
        await model.refreshRecommendations()
        XCTAssertEqual(model.recommendations, .loaded([meal("Bean burrito bowl", 480)]))
    }

    func testTheSameRequestIsNotSentTwice() async throws {
        let model = try await makeModel()
        recommender.meals = [meal("Bean chili", 450)]
        await model.refreshRecommendations()
        await model.refreshRecommendations()
        XCTAssertEqual(recommender.requests.count, 1)
    }

    func testLoggingAMealAsksAgainForTheNewBudget() async throws {
        let model = try await makeModel()
        recommender.meals = [meal("Bean chili", 450)]
        await model.refreshRecommendations()

        let feast = FoodItem(name: "Feast", grams: 100, base: Macros(kcal: 1_800, protein: 60, carbs: 0, fat: 0), confidence: .low)
        model.saveMeal(slot: .lunch, items: [feast], source: .text)
        await model.refreshRecommendations()

        XCTAssertEqual(recommender.requests.count, 2)
        XCTAssertEqual(recommender.requests.last??.budget, 400)
        XCTAssertEqual(model.recommendations, .loaded([]), "450 kcal no longer fits")
    }

    func testAskingForNewIdeasNamesTheOnesAlreadyShown() async throws {
        let model = try await makeModel()
        recommender.meals = [meal("Bean chili", 450), meal("Dal", 400)]
        await model.refreshRecommendations()
        recommender.meals = [meal("Shakshuka", 380)]

        await model.refreshRecommendations(force: true)

        XCTAssertEqual(recommender.requests.count, 2)
        XCTAssertEqual(recommender.avoided.last, ["Bean chili", "Dal"])
        XCTAssertEqual(model.recommendations, .loaded([meal("Shakshuka", 380)]))
    }

    func testNothingIsAskedOnceTheDayIsUsedUp() async throws {
        let model = try await makeModel()
        let feast = FoodItem(name: "Feast", grams: 100, base: Macros(kcal: 2_100, protein: 60, carbs: 0, fat: 0), confidence: .low)
        model.saveMeal(slot: .lunch, items: [feast], source: .text)
        XCTAssertNil(model.mealRequest)

        await model.refreshRecommendations()

        XCTAssertEqual(model.recommendations, .budgetUsed)
        XCTAssertTrue(recommender.requests.isEmpty)
    }

    func testAFailureCanBeRetried() async throws {
        let model = try await makeModel()
        recommender.failing = true
        await model.refreshRecommendations()
        XCTAssertEqual(model.recommendations, .failed)

        recommender.failing = false
        recommender.meals = [meal("Bean chili", 450)]
        await model.refreshRecommendations()
        XCTAssertEqual(model.recommendations, .loaded([meal("Bean chili", 450)]))
    }

    func testAUsedUpAIQuotaIsToldApartFromOtherFailures() async throws {
        let model = try await makeModel()
        recommender.failing = true
        recommender.error = GeminiClient.ClientError.badResponse(429)
        await model.refreshRecommendations()
        XCTAssertEqual(model.recommendations, .limitReached)

        recommender.error = MealRecommendationError.limitReached
        await model.refreshRecommendations()
        XCTAssertEqual(model.recommendations, .limitReached)

        recommender.error = MealRecommendationError.badResponse(500)
        await model.refreshRecommendations()
        XCTAssertEqual(model.recommendations, .failed)
    }

    func testTheSourceOfTheIdeasIsKnown() async throws {
        let model = try await makeModel()
        model.mealRecommender = SampleMealRecommender()
        XCTAssertEqual(model.recommendationSource, .sample)
        model.mealRecommender = GeminiMealRecommender(client: GeminiClient(apiKey: "test-key"))
        XCTAssertEqual(model.recommendationSource, .ai)
        model.mealRecommender = SpoonacularMealRecommender(apiKey: "test-key")
        XCTAssertEqual(model.recommendationSource, .recipeDatabase)
    }

    func testIdeasAreClearedOnSignOut() async throws {
        let model = try await makeModel()
        recommender.meals = [meal("Bean chili", 450)]
        await model.refreshRecommendations()
        model.signOut()
        XCTAssertEqual(model.recommendations, .idle)
    }

    // Canned ideas must never pass for ones matched to the person's diet.
    func testSampleIdeasAreFlagged() async throws {
        let model = try await makeModel()
        XCTAssertFalse(model.usesSampleRecommendations)
        model.mealRecommender = SampleMealRecommender(delay: .zero)
        XCTAssertTrue(model.usesSampleRecommendations)
        await model.refreshRecommendations()
        guard case .loaded(let meals) = model.recommendations else { return XCTFail("Expected sample ideas") }
        XCTAssertFalse(meals.isEmpty)
        XCTAssertTrue(meals.allSatisfy { $0.kcal <= 880 })
    }
}

private final class ScriptedRecommender: MealRecommending {
    struct Offline: Error {}

    var meals: [MealRecommendation] = []
    var failing = false
    var error: Error = Offline()
    private(set) var requests: [MealRequest?] = []
    private(set) var avoided: [[String]] = []

    func recommend(_ request: MealRequest, avoiding: [String]) async throws -> [MealRecommendation] {
        requests.append(request)
        avoided.append(avoiding)
        if failing { throw error }
        return meals
    }
}
