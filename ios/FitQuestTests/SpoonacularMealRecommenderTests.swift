import XCTest
@testable import FitQuest

final class SpoonacularMealRecommenderTests: XCTestCase {
    private let request = MealRequest(
        budget: 600, remainingProtein: 70, slot: .dinner, goal: .cut, diet: [.vegan, .nutAllergy]
    )

    override func tearDown() {
        StubProtocol.pages = [:]
        StubProtocol.statuses = []
    }

    private func query(_ request: MealRequest) throws -> [String: String] {
        let url = SpoonacularMealRecommender.url(for: request)
        XCTAssertEqual(url.host, "api.spoonacular.com")
        XCTAssertEqual(url.path, "/recipes/complexSearch")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    // MARK: Request

    func testSearchCarriesTheBudgetTheMealAndTheDiet() throws {
        let query = try query(request)
        XCTAssertEqual(query["maxCalories"], "600")
        XCTAssertEqual(query["minCalories"], "200", "A third of the budget, so sides and garnishes are not offered as dinner")
        XCTAssertEqual(query["type"], "main course")
        XCTAssertEqual(query["diet"], "vegan")
        XCTAssertEqual(query["intolerances"], "peanut,tree nut")
        XCTAssertEqual(query["number"], "10")
        XCTAssertEqual(query["addRecipeInformation"], "true")
        XCTAssertEqual(query["addRecipeNutrition"], "true")
        XCTAssertEqual(query["sort"], "random", "So asking again brings different recipes")
        XCTAssertNil(query["excludeIngredients"])
        XCTAssertNil(query["apiKey"], "The key travels in a header, never in the address")
    }

    func testMealTypeFollowsTheSlot() throws {
        var request = request
        request.slot = .breakfast
        XCTAssertEqual(try query(request)["type"], "breakfast")
        request.slot = .lunch
        XCTAssertEqual(try query(request)["type"], "main course")
        request.slot = .snack
        XCTAssertEqual(try query(request)["type"], "snack")
        XCTAssertNil(try query(request)["minCalories"], "A snack can be as small as it likes")
    }

    func testEveryDietMapsOntoTheDatabasesFilters() throws {
        var request = request
        request.diet = UserProfile.Diet.allCases
        let query = try query(request)
        XCTAssertEqual(query["diet"], "vegetarian,vegan,pescetarian")
        XCTAssertEqual(query["intolerances"], "shellfish,gluten,dairy,peanut,tree nut")
        // Halal and kosher have no filter of their own; what can be excluded by ingredient is.
        let excluded = Set(try XCTUnwrap(query["excludeIngredients"]).split(separator: ",").map(String.init))
        XCTAssertTrue(excluded.isSuperset(of: ["pork", "bacon", "ham", "wine", "beer"]), "\(excluded)")
    }

    func testNoDietMeansNoDietFilters() throws {
        var request = request
        request.diet = []
        let query = try query(request)
        XCTAssertNil(query["diet"])
        XCTAssertNil(query["intolerances"])
        XCTAssertNil(query["excludeIngredients"])
    }

    // MARK: Response

    private let twoRecipes = #"""
    {"results":[
      {"id":716426,"title":" Cauliflower Fried Rice ","sourceUrl":"http://example.com/cauliflower-fried-rice/",
       "spoonacularSourceUrl":"https://spoonacular.com/cauliflower-fried-rice-716426",
       "nutrition":{"nutrients":[{"name":"Calories","amount":191.83,"unit":"kcal"},{"name":"Fat","amount":3.2,"unit":"g"},{"name":"Protein","amount":6.93,"unit":"g"}],
                    "ingredients":[{"id":1,"name":"cauliflower"},{"id":2,"name":"brown rice"}]}},
      {"id":2,"title":"Lentil Soup","sourceUrl":"https://example.com/lentil-soup/",
       "spoonacularSourceUrl":"https://spoonacular.com/lentil-soup-2",
       "nutrition":{"nutrients":[{"name":"Protein","amount":18,"unit":"g"},{"name":"Calories","amount":350,"unit":"kcal"}]}}
    ],"offset":0,"number":8,"totalResults":2}
    """#

    func testParsesRecipes() throws {
        let recipes = try SpoonacularMealRecommender.parse(Data(twoRecipes.utf8))
        XCTAssertEqual(recipes, [
            SpoonacularMealRecommender.Recipe(
                title: "Cauliflower Fried Rice", kcal: 192, protein: 7, ingredients: ["cauliflower", "brown rice"],
                // An old plain-http address is tried over https.
                source: URL(string: "https://example.com/cauliflower-fried-rice/"),
                page: URL(string: "https://spoonacular.com/cauliflower-fried-rice-716426")
            ),
            SpoonacularMealRecommender.Recipe(
                title: "Lentil Soup", kcal: 350, protein: 18, ingredients: [],
                source: URL(string: "https://example.com/lentil-soup/"), page: URL(string: "https://spoonacular.com/lentil-soup-2")
            ),
        ])
    }

    func testRecipesWithoutCaloriesOrAnyLinkAreLeftOut() throws {
        let recipes = try SpoonacularMealRecommender.parse(Data(#"""
        {"results":[
          {"id":1,"title":"No numbers","sourceUrl":"https://example.com/a/","nutrition":{"nutrients":[]}},
          {"id":2,"title":"No links","nutrition":{"nutrients":[{"name":"Calories","amount":300,"unit":"kcal"}]}},
          {"id":3,"title":"","sourceUrl":"https://example.com/c/","nutrition":{"nutrients":[{"name":"Calories","amount":300,"unit":"kcal"}]}},
          {"id":4,"title":"Kept","sourceUrl":"https://example.com/d/","nutrition":{"nutrients":[{"name":"Calories","amount":300,"unit":"kcal"}]}}
        ]}
        """#.utf8))
        XCTAssertEqual(recipes.map(\.title), ["Kept"])
        XCTAssertEqual(recipes.first?.protein, 0)
    }

    // MARK: End to end

    private func stubbed(_ json: String, statuses: [Int] = []) -> SpoonacularMealRecommender {
        StubProtocol.statuses = statuses
        StubProtocol.requests = 0
        StubProtocol.urls = []
        StubProtocol.body = Data(json.utf8)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: config)
        return SpoonacularMealRecommender(apiKey: "test-key", session: session, checker: RecipeLinkChecker(session: session))
    }

    // Every idea gets a link that works: the original recipe when it still opens, the database's own page otherwise.
    func testEveryRecipeGetsAWorkingLink() async throws {
        let recommender = stubbed(twoRecipes)
        StubProtocol.pages = [
            "https://example.com/cauliflower-fried-rice/": (404, ""),
            "https://example.com/lentil-soup/": (200, #"<html><head><title>Lentil Soup | A Blog</title></head></html>"#),
        ]

        let meals = try await recommender.recommend(request, avoiding: [])

        XCTAssertEqual(meals, [
            MealRecommendation(name: "Cauliflower Fried Rice", kcal: 192, protein: 7, link: URL(string: "https://spoonacular.com/cauliflower-fried-rice-716426")),
            MealRecommendation(name: "Lentil Soup", kcal: 350, protein: 18, link: URL(string: "https://example.com/lentil-soup/")),
        ])
        XCTAssertEqual(StubProtocol.requests, 1, "One search, whatever the number of recipes")
    }

    // Most of the database's recipes come from a site that turns scripts away. Its links still work for people.
    func testASourceThatBlocksTheCheckIsStillLinked() async throws {
        let recommender = stubbed(twoRecipes)
        StubProtocol.pages = [
            "https://example.com/cauliflower-fried-rice/": (429, "<html><head><title>Security Checkpoint</title></head></html>"),
            "https://example.com/lentil-soup/": (200, "<html><head><title>Home | A Blog</title></head></html>"),
        ]
        let meals = try await recommender.recommend(request, avoiding: [])
        XCTAssertEqual(meals.map(\.link?.absoluteString), [
            "https://example.com/cauliflower-fried-rice/",
            "https://spoonacular.com/lentil-soup-2",
        ])
    }

    // The database labelled a hazelnut salad as free of tree nuts, so its labels are not taken on trust.
    func testRecipesThatBreakTheDietInTheirOwnWordsAreDropped() async throws {
        let recommender = stubbed(#"""
        {"results":[
          {"id":1,"title":"Squash Salad With Toasted Hazelnuts","spoonacularSourceUrl":"https://spoonacular.com/a-1",
           "nutrition":{"nutrients":[{"name":"Calories","amount":261}],"ingredients":[{"name":"squash"}]}},
          {"id":2,"title":"Soba Noodle Salad","spoonacularSourceUrl":"https://spoonacular.com/b-2",
           "nutrition":{"nutrients":[{"name":"Calories","amount":452}],"ingredients":[{"name":"soba noodles"},{"name":"peanut butter"}]}},
          {"id":3,"title":"White Bean Soup","spoonacularSourceUrl":"https://spoonacular.com/c-3",
           "nutrition":{"nutrients":[{"name":"Calories","amount":300}],"ingredients":[{"name":"navy beans"},{"name":"parmesan rind"}]}},
          {"id":4,"title":"Indian Lentil Dahl","spoonacularSourceUrl":"https://spoonacular.com/d-4",
           "nutrition":{"nutrients":[{"name":"Calories","amount":400}],"ingredients":[{"name":"lentils"},{"name":"coconut milk"}]}}
        ]}
        """#)
        let meals = try await recommender.recommend(request, avoiding: [])
        XCTAssertEqual(meals.map(\.name), ["Indian Lentil Dahl"])
    }

    func testRecipesAlreadyShownAreNotOfferedAgain() async throws {
        let meals = try await stubbed(twoRecipes).recommend(request, avoiding: ["lentil soup"])
        XCTAssertEqual(meals.map(\.name), ["Cauliflower Fried Rice"])
    }

    func testAUsedUpDailyAllowanceIsReportedAsSuch() async {
        for status in [402, 429] {
            do {
                _ = try await stubbed(twoRecipes, statuses: [status]).recommend(request, avoiding: [])
                XCTFail("Expected an error")
            } catch {
                XCTAssertEqual(error as? MealRecommendationError, .limitReached, "\(status)")
            }
        }
    }

    func testOtherFailuresAreNotMistakenForTheAllowance() async {
        do {
            _ = try await stubbed(twoRecipes, statuses: [401]).recommend(request, avoiding: [])
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? MealRecommendationError, .badResponse(401))
        }
    }

    /// Calls the real API. Opt-in: `SPOONACULAR_API_KEY=... swift test --filter testLiveRecipes`
    func testLiveRecipes() async throws {
        guard let key = ProcessInfo.processInfo.environment["SPOONACULAR_API_KEY"], !key.isEmpty else {
            throw XCTSkip("Set SPOONACULAR_API_KEY to call Spoonacular")
        }
        let meals = try await SpoonacularMealRecommender(apiKey: key).recommend(request, avoiding: [])
        for meal in meals {
            print("LIVE:", meal.name, "|", meal.kcal, "kcal |", meal.protein, "g protein |", meal.link?.absoluteString ?? "no link")
        }
        XCTAssertGreaterThanOrEqual(meals.count, 3)
        XCTAssertTrue(meals.allSatisfy { $0.kcal <= 600 && $0.link != nil })
    }
}
