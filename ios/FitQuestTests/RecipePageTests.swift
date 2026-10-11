import XCTest
@testable import FitQuest

final class RecipePageTests: XCTestCase {
    private func html(_ jsonLD: String, title: String = "A page") -> String {
        "<html><head><title>\(title)</title><script type=\"application/ld+json\">\(jsonLD)</script></head><body></body></html>"
    }

    // MARK: Reading a page

    func testReadsTheRecipeAndItsNutrition() {
        let page = RecipePage.parse(html: html(#"""
        {"@context":"https://schema.org","@type":"Recipe","name":"Lentil Soup",
         "nutrition":{"@type":"NutritionInformation","calories":"386 kcal","proteinContent":"19 g"}}
        """#))
        XCTAssertEqual(page, RecipePage(name: "Lentil Soup", kcal: 386, protein: 19))
    }

    func testFindsTheRecipeInsideAGraphOrAList() {
        let graph = RecipePage.parse(html: html(#"""
        {"@context":"https://schema.org","@graph":[{"@type":"WebSite","name":"Some Blog"},
         {"@type":["Recipe","NewsArticle"],"name":"Black Bean Chili","nutrition":{"calories":"368 calories","proteinContent":"12.6g"}}]}
        """#))
        XCTAssertEqual(graph, RecipePage(name: "Black Bean Chili", kcal: 368, protein: 13))

        let list = RecipePage.parse(html: html(#"[{"@type":"BreadcrumbList"},{"@type":"Recipe","name":"Dal","nutrition":{"calories":278}}]"#))
        XCTAssertEqual(list, RecipePage(name: "Dal", kcal: 278, protein: nil))
    }

    func testARecipeWithoutNutritionStillCounts() {
        let page = RecipePage.parse(html: html(#"{"@type":"Recipe","name":"Shakshuka"}"#))
        XCTAssertEqual(page, RecipePage(name: "Shakshuka", kcal: nil, protein: nil))
    }

    func testFallsBackToThePageTitle() {
        let page = RecipePage.parse(html: html(#"{"@type":"WebSite","name":"Some Blog"}"#, title: " Tofu &amp; Broccoli Stir-Fry | Some Blog "))
        XCTAssertEqual(page, RecipePage(name: "Tofu & Broccoli Stir-Fry | Some Blog", kcal: nil, protein: nil))
        XCTAssertEqual(RecipePage.parse(html: "<html><head><TITLE>Plain</TITLE></head></html>")?.name, "Plain")
    }

    func testBrokenMarkupIsNotAPage() {
        XCTAssertNil(RecipePage.parse(html: "<html><body>Nothing here</body></html>"))
        XCTAssertEqual(RecipePage.parse(html: html("{not json", title: "Still titled"))?.name, "Still titled")
    }

    func testAbsurdNutritionIsIgnored() {
        let page = RecipePage.parse(html: html(#"{"@type":"Recipe","name":"Cake","nutrition":{"calories":"0","proteinContent":"-3 g"}}"#))
        XCTAssertEqual(page, RecipePage(name: "Cake", kcal: nil, protein: nil))
    }

    // MARK: Is it the right dish?

    func testAPageIsAboutADishWhenMostOfTheNameIsThere() {
        XCTAssertTrue(RecipePage(name: "Lentil Soup (seriously amazing!) - RecipeTin Eats").isAbout("Lentil Soup"))
        XCTAssertTrue(RecipePage(name: "Sweet Potato & Black Bean Chili").isAbout("Sweet Potato and Black Bean Chili"))
        XCTAssertTrue(RecipePage(name: "General Tso's Tofu Stir-Fry | Minimalist Baker").isAbout("General Tso’s Tofu"))
        XCTAssertTrue(RecipePage(name: "Easy Black Bean Taco Recipe").isAbout("Quick Black Bean Tacos"))
    }

    func testAPageAboutSomethingElseIsRejected() {
        XCTAssertFalse(RecipePage(name: "Page Not Found").isAbout("Lentil Soup"))
        XCTAssertFalse(RecipePage(name: "Recipes - Some Blog").isAbout("Vegetarian Tikka Masala"))
        XCTAssertFalse(RecipePage(name: "Chicken Soup").isAbout("Lentil Soup with Spinach"))
        XCTAssertFalse(RecipePage(name: "Lentil Soup").isAbout(""))
    }

    // MARK: Fetching

    private func checker() -> RecipeLinkChecker {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return RecipeLinkChecker(session: URLSession(configuration: config))
    }

    override func tearDown() {
        StubProtocol.pages = [:]
    }

    func testALiveMatchingPageIsConfirmed() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/lentil-soup/"))
        StubProtocol.pages = [url.absoluteString: (200, html(#"{"@type":"Recipe","name":"Lentil Soup","nutrition":{"calories":"386 kcal"}}"#))]
        let page = await checker().page(at: url, about: "Lentil Soup")
        XCTAssertEqual(page, RecipePage(name: "Lentil Soup", kcal: 386, protein: nil))
    }

    /// Opens real recipe sites. Opt-in: `FQ_LIVE_LINKS=1 swift test --filter testLiveRecipeLinks`
    func testLiveRecipeLinks() async throws {
        guard ProcessInfo.processInfo.environment["FQ_LIVE_LINKS"] != nil else { throw XCTSkip("Set FQ_LIVE_LINKS to open real pages") }
        let checker = RecipeLinkChecker()
        let real = try XCTUnwrap(URL(string: "https://www.recipetineats.com/lentil-soup/"))
        let page = await checker.page(at: real, about: "Lentil Soup")
        print("LIVE:", page as Any)
        XCTAssertNotNil(page)
        let madeUp = try XCTUnwrap(URL(string: "https://www.skinnytaste.com/mediterranean-lentil-salad/"))
        let missing = await checker.page(at: madeUp, about: "Mediterranean Lentil Salad")
        XCTAssertNil(missing, "A 'page not found' must not pass for a recipe")
    }

    // Sites behind a bot check turn the app away but open normally in a browser.
    func testASiteThatTurnsScriptsAwayIsBlockedNotMissing() async throws {
        let blocked = try XCTUnwrap(URL(string: "https://example.com/blocked/"))
        let gone = try XCTUnwrap(URL(string: "https://example.com/gone/"))
        let real = try XCTUnwrap(URL(string: "https://example.com/lentil-soup/"))
        StubProtocol.pages = [
            blocked.absoluteString: (429, "<html><head><title>Security Checkpoint</title></head></html>"),
            gone.absoluteString: (404, ""),
            real.absoluteString: (200, html(#"{"@type":"Recipe","name":"Lentil Soup"}"#)),
        ]
        let checker = checker()
        let results = [
            await checker.check(blocked, about: "Lentil Soup"),
            await checker.check(gone, about: "Lentil Soup"),
            await checker.check(real, about: "Lentil Soup"),
        ]
        XCTAssertEqual(results, [.blocked, .missing, .confirmed(RecipePage(name: "Lentil Soup"))])
        let page = await checker.page(at: blocked, about: "Lentil Soup")
        XCTAssertNil(page, "Blocked is not confirmed")
    }

    func testMissingWrongAndInsecurePagesAreNotConfirmed() async throws {
        let gone = try XCTUnwrap(URL(string: "https://example.com/gone/"))
        let other = try XCTUnwrap(URL(string: "https://example.com/other/"))
        let insecure = try XCTUnwrap(URL(string: "http://example.com/lentil-soup/"))
        StubProtocol.pages = [
            gone.absoluteString: (404, html(#"{"@type":"Recipe","name":"Lentil Soup"}"#)),
            other.absoluteString: (200, html("{}", title: "Home - Some Blog")),
            insecure.absoluteString: (200, html(#"{"@type":"Recipe","name":"Lentil Soup"}"#)),
        ]
        let checker = checker()
        let results = [
            await checker.page(at: gone, about: "Lentil Soup"),
            await checker.page(at: other, about: "Lentil Soup"),
            await checker.page(at: insecure, about: "Lentil Soup"),
        ]
        XCTAssertEqual(results, [nil, nil, nil])
    }
}
