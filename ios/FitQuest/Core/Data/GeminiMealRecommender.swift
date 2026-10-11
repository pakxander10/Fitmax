import Foundation

/// Asks Gemini for recipes that fit a calorie budget and a diet. Gemini only proposes:
/// the budget is worked out before the call and checked again on what comes back, and
/// every recipe link is opened to confirm it exists, because Gemini recalls many addresses wrongly.
struct GeminiMealRecommender: MealRecommending {
    /// How many ideas are shown.
    static let count = 4
    /// How many are asked for. In practice about one address in three checks out, so ask for spares.
    static let asked = 8

    var client: GeminiClient
    var checker = RecipeLinkChecker()

    /// Nil when no Gemini key is configured.
    static func fromConfig(bundle: Bundle = .main) -> GeminiMealRecommender? {
        GeminiClient.fromConfig(bundle: bundle).map { GeminiMealRecommender(client: $0) }
    }

    func recommend(_ request: MealRequest, avoiding: [String]) async throws -> [MealRecommendation] {
        let candidates = try Self.parse(try await client.send(Self.body(for: request, avoiding: avoiding)))
        let checked = await withTaskGroup(of: (Int, MealRecommendation).self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask { (index, await confirm(candidate)) }
            }
            var results: [(Int, MealRecommendation)] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        // Ideas with a link that checked out go first.
        return checked.filter { $0.link != nil } + checked.filter { $0.link == nil }
    }

    /// Keeps the link only if it opens the right recipe, and prefers the page's own nutrition figures.
    private func confirm(_ candidate: MealRecommendation) async -> MealRecommendation {
        guard let link = candidate.link, let page = await checker.page(at: link, about: candidate.name) else {
            return MealRecommendation(name: candidate.name, kcal: candidate.kcal, protein: candidate.protein, link: nil)
        }
        return MealRecommendation(
            name: candidate.name, kcal: page.kcal ?? candidate.kcal, protein: page.protein ?? candidate.protein, link: link
        )
    }

    // MARK: Request

    static func body(for request: MealRequest, avoiding: [String]) -> [String: Any] {
        let number: [String: Any] = ["type": "INTEGER"]
        return [
            "contents": [["parts": [["text": prompt(for: request, avoiding: avoiding)]]]],
            "generationConfig": [
                "thinkingConfig": ["thinkingLevel": "low"],
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": ["items": [
                        "type": "ARRAY",
                        "items": [
                            "type": "OBJECT",
                            "properties": [
                                "name": ["type": "STRING"],
                                "kcal": number, "protein": number,
                                "url": ["type": "STRING"],
                            ],
                            "required": ["name", "kcal", "protein", "url"],
                        ],
                    ]],
                    "required": ["items"],
                ],
            ],
        ]
    }

    static func prompt(for request: MealRequest, avoiding: [String]) -> String {
        var lines = [
            "You suggest recipes for a fitness app. Suggest \(asked) different \(request.slot.rawValue) recipes that are published on well-known recipe websites.",
            "Each one must come to at most \(request.budget) kcal for one serving. Be conservative: if in doubt, pick something lighter.",
        ]
        if request.remainingProtein > 0 {
            lines.append("They still have about \(request.remainingProtein) g of protein to eat today, so favour protein-rich choices.")
        }
        if let goal = request.goal {
            lines.append("Their goal is to \(goal.label.lowercased()).")
        }
        if request.diet.isEmpty {
            lines.append("They have no dietary restrictions.")
        } else {
            lines.append("Dietary rules. These are strict, and every recipe must follow all of them:")
            lines += request.diet.map { "- \($0.rule)" }
        }
        if !avoiding.isEmpty {
            lines.append("Do not suggest any of these again: \(avoiding.joined(separator: "; ")).")
        }
        lines.append("""
        For each recipe give: name, a short plain name for the dish of at most six words; kcal and protein, \
        whole numbers for one serving (protein in grams); and url, the exact web address of that recipe's page. \
        Only give an address you are confident exists exactly as written; otherwise leave url empty. \
        Prefer long-established recipes on large sites, use several different sites, and vary the cuisines.
        """)
        return lines.joined(separator: "\n")
    }

    // MARK: Response

    private struct Payload: Decodable {
        struct Item: Decodable {
            var name: String
            var kcal: Int
            var protein: Int
            var url: String
        }
        var items: [Item]
    }

    /// Gemini's suggestions, links not yet checked. Meals with no name or no calories are left out.
    static func parse(_ data: Data) throws -> [MealRecommendation] {
        try GeminiClient.decode(Payload.self, from: data).items.compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, item.kcal > 0 else { return nil }
            let link = URL(string: item.url.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.scheme == "https" ? $0 : nil }
            return MealRecommendation(name: name, kcal: item.kcal, protein: max(0, item.protein), link: link)
        }
    }
}
