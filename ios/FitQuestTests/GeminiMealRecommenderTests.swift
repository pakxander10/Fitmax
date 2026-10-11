import XCTest
@testable import FitQuest

final class GeminiMealRecommenderTests: XCTestCase {
    private let request = MealRequest(
        budget: 600, remainingProtein: 70, slot: .dinner, goal: .cut, diet: [.vegan, .nutAllergy]
    )

    override func tearDown() {
        StubProtocol.pages = [:]
    }

    private func envelope(_ json: String) -> Data {
        let wrapper: [String: Any] = ["candidates": [["content": ["parts": [["text": json]]]]]]
        return try! JSONSerialization.data(withJSONObject: wrapper)
    }

    private func prompt(_ request: MealRequest, avoiding: [String] = []) throws -> String {
        let body = GeminiMealRecommender.body(for: request, avoiding: avoiding)
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])
        return parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
    }

    // MARK: Request

    func testPromptCarriesTheBudgetTheMealAndEveryDietRule() throws {
        let text = try prompt(request)
        XCTAssertTrue(text.contains("600 kcal"), text)
        XCTAssertTrue(text.contains("dinner"), text)
        XCTAssertTrue(text.contains("70 g of protein"), text)
        XCTAssertTrue(text.contains("lose fat"), text)
        XCTAssertTrue(text.contains("web address"), text)
        for diet in request.diet {
            XCTAssertTrue(text.contains(diet.rule), diet.rule)
        }
        XCTAssertFalse(text.contains(UserProfile.Diet.halal.rule))
    }

    func testPromptSaysSoWhenThereAreNoDietRules() throws {
        var open = request
        open.diet = []
        open.goal = nil
        let text = try prompt(open)
        XCTAssertTrue(text.contains("no dietary restrictions"), text)
        for diet in UserProfile.Diet.allCases {
            XCTAssertFalse(text.contains(diet.rule), diet.rule)
        }
    }

    func testPromptListsMealsNotToRepeat() throws {
        XCTAssertFalse(try prompt(request).contains("Do not suggest"))
        let text = try prompt(request, avoiding: ["Lentil curry", "Tofu stir-fry"])
        XCTAssertTrue(text.contains("Do not suggest any of these again: Lentil curry; Tofu stir-fry."), text)
    }

    func testRequestAsksForStructuredJSON() throws {
        let body = GeminiMealRecommender.body(for: request, avoiding: [])
        let config = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        XCTAssertEqual(config["responseMimeType"] as? String, "application/json")
        let schema = try XCTUnwrap(config["responseSchema"] as? [String: Any])
        let items = try XCTUnwrap((schema["properties"] as? [String: Any])?["items"] as? [String: Any])
        let item = try XCTUnwrap(items["items"] as? [String: Any])
        XCTAssertEqual(Set(try XCTUnwrap(item["required"] as? [String])), ["name", "kcal", "protein", "url"])
    }

    // MARK: Response

    func testParsesCandidates() throws {
        let candidates = try GeminiMealRecommender.parse(envelope(#"""
        {"items":[{"name":" Lentil curry with rice ","kcal":520,"protein":24,"url":"https://example.com/lentil-curry/"},
                  {"name":"Tofu poke bowl","kcal":480,"protein":30,"url":"not a link"}]}
        """#))
        XCTAssertEqual(candidates, [
            MealRecommendation(name: "Lentil curry with rice", kcal: 520, protein: 24, link: URL(string: "https://example.com/lentil-curry/")),
            MealRecommendation(name: "Tofu poke bowl", kcal: 480, protein: 30, link: nil),
        ])
    }

    func testUnusableMealsAreLeftOut() throws {
        let meals = try GeminiMealRecommender.parse(envelope(#"""
        {"items":[{"name":"","kcal":300,"protein":10,"url":""},
                  {"name":"Air","kcal":0,"protein":0,"url":""},
                  {"name":"Bean chili","kcal":450,"protein":-4,"url":""}]}
        """#))
        XCTAssertEqual(meals, [MealRecommendation(name: "Bean chili", kcal: 450, protein: 0, link: nil)])
    }

    func testEmptyAndMissingContent() throws {
        XCTAssertTrue(try GeminiMealRecommender.parse(envelope(#"{"items":[]}"#)).isEmpty)
        XCTAssertThrowsError(try GeminiMealRecommender.parse(Data(#"{"candidates":[]}"#.utf8)))
    }

    // MARK: Link checking

    private func stubbed(_ json: String, statuses: [Int] = []) -> GeminiMealRecommender {
        StubProtocol.statuses = statuses
        StubProtocol.requests = 0
        StubProtocol.body = envelope(json)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let session = URLSession(configuration: config)
        return GeminiMealRecommender(
            client: GeminiClient(apiKey: "test-key", session: session, retryDelay: .zero),
            checker: RecipeLinkChecker(session: session)
        )
    }

    private func recipePage(_ name: String, kcal: Int? = nil) -> String {
        let nutrition = kcal.map { #","nutrition":{"calories":"\#($0) kcal","proteinContent":"21 g"}"# } ?? ""
        return #"<html><head><script type="application/ld+json">{"@type":"Recipe","name":"\#(name)"\#(nutrition)}</script></head></html>"#
    }

    // Gemini recalls addresses from memory and gets many wrong, so only links that open the right recipe are kept.
    func testOnlyLinksThatOpenTheRightRecipeAreKept() async throws {
        let recommender = stubbed(#"""
        {"items":[{"name":"Made-up stew","kcal":400,"protein":20,"url":"https://example.com/made-up-stew/"},
                  {"name":"Lentil soup","kcal":350,"protein":18,"url":"https://example.com/lentil-soup/"},
                  {"name":"Bean tacos","kcal":420,"protein":19,"url":"https://example.com/bean-tacos/"},
                  {"name":"Tofu scramble","kcal":300,"protein":22,"url":"https://example.com/tofu-scramble/"}]}
        """#)
        StubProtocol.pages = [
            "https://example.com/made-up-stew/": (404, ""),
            "https://example.com/lentil-soup/": (200, recipePage("Lentil Soup", kcal: 386)),
            "https://example.com/bean-tacos/": (200, recipePage("Chocolate Cake")),
            "https://example.com/tofu-scramble/": (200, recipePage("Easy Tofu Scramble")),
        ]

        let meals = try await recommender.recommend(request, avoiding: [])

        XCTAssertEqual(meals, [
            // Checked links come first, with the recipe page's own nutrition when it gives any.
            MealRecommendation(name: "Lentil soup", kcal: 386, protein: 21, link: URL(string: "https://example.com/lentil-soup/")),
            MealRecommendation(name: "Tofu scramble", kcal: 300, protein: 22, link: URL(string: "https://example.com/tofu-scramble/")),
            MealRecommendation(name: "Made-up stew", kcal: 400, protein: 20, link: nil),
            MealRecommendation(name: "Bean tacos", kcal: 420, protein: 19, link: nil),
        ])
    }

    func testRetriesThroughABusyServer() async throws {
        let recommender = stubbed(#"{"items":[{"name":"Bean chili","kcal":450,"protein":28,"url":""}]}"#, statuses: [503])

        let meals = try await recommender.recommend(request, avoiding: [])

        XCTAssertEqual(meals.map(\.name), ["Bean chili"])
        XCTAssertEqual(StubProtocol.requests, 2)
    }

    /// Calls the real API and the real recipe sites. Opt-in, so normal runs never spend quota:
    /// `GEMINI_API_KEY=... swift test --filter testLiveMealIdeas`
    func testLiveMealIdeas() async throws {
        guard let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty else {
            throw XCTSkip("Set GEMINI_API_KEY to call Gemini")
        }
        let meals = try await GeminiMealRecommender(client: GeminiClient(apiKey: key)).recommend(request, avoiding: [])
        for meal in meals {
            print("LIVE:", meal.name, "|", meal.kcal, "kcal |", meal.protein, "g protein |", meal.link?.absoluteString ?? "no checked link")
        }
        // How many links check out varies from run to run, so only the ideas themselves are required.
        XCTAssertGreaterThanOrEqual(meals.count, 3)
    }
}
