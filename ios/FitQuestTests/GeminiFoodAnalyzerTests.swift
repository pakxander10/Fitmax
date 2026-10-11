import XCTest
@testable import FitQuest

final class GeminiFoodAnalyzerTests: XCTestCase {
    private func envelope(_ json: String) -> Data {
        let wrapper: [String: Any] = ["candidates": [["content": ["parts": [["text": json]]]]]]
        return try! JSONSerialization.data(withJSONObject: wrapper)
    }

    func testParsesItems() throws {
        let items = try GeminiFoodAnalyzer.parse(envelope(
            #"{"items":[{"name":"Rice","grams":180,"kcal":202,"protein":5,"carbs":42,"fat":2,"confidence":"High"}]}"#))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "Rice")
        XCTAssertEqual(items[0].macros, Macros(kcal: 202, protein: 5, carbs: 42, fat: 2))
        XCTAssertEqual(items[0].confidence, .high)
    }

    func testParsesAServingWhenGeminiGivesOne() throws {
        let items = try GeminiFoodAnalyzer.parse(envelope(
            #"{"items":[{"name":"Boiled eggs","grams":100,"kcal":155,"protein":13,"carbs":1,"fat":11,"confidence":"high","serving_name":" 1 Egg ","serving_grams":50}]}"#))
        XCTAssertEqual(items[0].serving, Serving(name: "egg", grams: 50))
    }

    func testServingIsDroppedWhenMissingOrUnusable() throws {
        let items = try GeminiFoodAnalyzer.parse(envelope(#"""
        {"items":[
          {"name":"Stew","grams":300,"kcal":320,"protein":20,"carbs":25,"fat":14,"confidence":"low"},
          {"name":"Rice","grams":180,"kcal":202,"protein":5,"carbs":42,"fat":2,"confidence":"high","serving_name":"cup","serving_grams":0},
          {"name":"Soup","grams":250,"kcal":120,"protein":6,"carbs":14,"fat":4,"confidence":"low","serving_name":"","serving_grams":240}
        ]}
        """#))
        XCTAssertEqual(items.map(\.serving), [nil, nil, nil])
    }

    func testRequestAsksForServingsButDoesNotRequireThem() throws {
        let body = GeminiFoodAnalyzer.body(for: .text("2 eggs"))
        let config = try XCTUnwrap(body["generationConfig"] as? [String: Any])
        let schema = try XCTUnwrap(config["responseSchema"] as? [String: Any])
        let list = try XCTUnwrap((schema["properties"] as? [String: Any])?["items"] as? [String: Any])
        let item = try XCTUnwrap(list["items"] as? [String: Any])
        let properties = try XCTUnwrap(item["properties"] as? [String: Any])
        let required = try XCTUnwrap(item["required"] as? [String])
        XCTAssertNotNil(properties["serving_name"])
        XCTAssertNotNil(properties["serving_grams"])
        XCTAssertFalse(required.contains("serving_name"))
        XCTAssertFalse(required.contains("serving_grams"))
    }

    func testEmptyListMeansNoFood() throws {
        XCTAssertTrue(try GeminiFoodAnalyzer.parse(envelope(#"{"items":[]}"#)).isEmpty)
    }

    func testMissingContentThrows() {
        XCTAssertThrowsError(try GeminiFoodAnalyzer.parse(Data(#"{"candidates":[]}"#.utf8)))
    }

    // MARK: Retries

    private func stubbedAnalyzer(statuses: [Int]) -> GeminiFoodAnalyzer {
        StubProtocol.statuses = statuses
        StubProtocol.requests = 0
        StubProtocol.urls = []
        StubProtocol.body = envelope(#"{"items":[{"name":"Rice","grams":180,"kcal":202,"protein":5,"carbs":42,"fat":2,"confidence":"high"}]}"#)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return GeminiFoodAnalyzer(apiKey: "test-key", session: URLSession(configuration: config), retryDelay: .zero)
    }

    // Gemini often answers 503 when busy; one blip must not fail the meal log.
    func testRetriesThroughTransientErrors() async throws {
        let analyzer = stubbedAnalyzer(statuses: [503, 429])
        let items = try await analyzer.estimate(.text("rice"))
        XCTAssertEqual(items.map(\.name), ["Rice"])
        XCTAssertEqual(StubProtocol.requests, 3)
    }

    func testGivesUpAfterThreeAttempts() async {
        let analyzer = stubbedAnalyzer(statuses: [503, 503, 503, 503])
        do {
            _ = try await analyzer.estimate(.text("rice"))
            XCTFail("expected a failure")
        } catch GeminiFoodAnalyzer.AnalyzerError.badResponse(let status) {
            XCTAssertEqual(status, 503)
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertEqual(StubProtocol.requests, 3)
    }

    // The free tier allows a small number of requests a day for each model, counted separately.
    func testAUsedUpQuotaMovesOnToTheNextModel() async throws {
        let analyzer = stubbedAnalyzer(statuses: [429])
        let items = try await analyzer.estimate(.text("rice"))
        XCTAssertEqual(items.map(\.name), ["Rice"])
        XCTAssertEqual(StubProtocol.urls.count, 2)
        XCTAssertTrue(StubProtocol.urls[0].contains("/\(analyzer.client.model):generateContent"))
        XCTAssertTrue(StubProtocol.urls[1].contains("/\(analyzer.client.fallbackModels[0]):generateContent"))
    }

    func testReportsTheQuotaWhenEveryModelIsUsedUp() async {
        let analyzer = stubbedAnalyzer(statuses: Array(repeating: 429, count: 10))
        do {
            _ = try await analyzer.estimate(.text("rice"))
            XCTFail("expected a failure")
        } catch GeminiFoodAnalyzer.AnalyzerError.badResponse(let status) {
            XCTAssertEqual(status, 429)
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertEqual(StubProtocol.requests, 1 + analyzer.client.fallbackModels.count)
    }

    func testDoesNotRetryARejectedRequest() async {
        let analyzer = stubbedAnalyzer(statuses: [400])
        do {
            _ = try await analyzer.estimate(.text("rice"))
            XCTFail("expected a failure")
        } catch {}
        XCTAssertEqual(StubProtocol.requests, 1)
    }

    /// Calls the real API. Opt-in, so normal runs never spend quota:
    /// `GEMINI_API_KEY=... swift test --filter testLiveTextEstimate`
    func testLiveTextEstimate() async throws {
        guard let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty else {
            throw XCTSkip("Set GEMINI_API_KEY to call Gemini")
        }
        let items = try await GeminiFoodAnalyzer(apiKey: key).estimate(.text("2 boiled eggs, a slice of toast and a bowl of beef stew"))
        for item in items {
            print("LIVE:", item.name, "|", item.amountText, "g |", item.macros.kcal, "kcal |", item.serving.map { "serving: \($0.name) \($0.grams) g" } ?? "no serving")
        }
        XCTAssertGreaterThanOrEqual(items.count, 2)
        XCTAssertTrue(items.contains { $0.serving != nil }, "eggs and toast should come back with a serving")
        XCTAssertTrue(items.allSatisfy { $0.macros.kcal > 0 })
    }
}

/// Answers every request from a queue of status codes, then 200 with `body`.
/// Addresses listed in `pages` are answered from there instead, and not counted.
final class StubProtocol: URLProtocol {
    static var statuses: [Int] = []
    static var requests = 0
    static var body = Data()
    static var pages: [String: (status: Int, html: String)] = [:]
    /// The address of every counted request, in order.
    static var urls: [String] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        if let page = request.url.flatMap({ Self.pages[$0.absoluteString] }) {
            let response = HTTPURLResponse(url: request.url!, statusCode: page.status, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(page.html.utf8))
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        Self.requests += 1
        Self.urls.append(request.url?.absoluteString ?? "")
        let status = Self.statuses.isEmpty ? 200 : Self.statuses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: status == 200 ? Self.body : Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
