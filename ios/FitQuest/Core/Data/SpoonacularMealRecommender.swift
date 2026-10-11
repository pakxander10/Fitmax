import Foundation

/// Finds real recipes in the Spoonacular database that fit a calorie budget and a diet.
/// The calorie and diet filtering is the database's, on its own nutrition data; no AI picks the meals.
/// Its diet labels are then checked against each recipe's ingredient list, because some are wrong.
struct SpoonacularMealRecommender: MealRecommending {
    /// How many recipes one search asks for, to leave spares once repeats and unsuitable ones are dropped.
    static let asked = 10

    /// One search result, before its link has been checked.
    struct Recipe: Equatable {
        var title: String
        var kcal: Int
        var protein: Int
        var ingredients: [String]
        /// The site the recipe was first published on. Some of these have since gone away.
        var source: URL?
        /// The database's own page for the recipe, which always opens.
        var page: URL?
    }

    var apiKey: String
    var session: URLSession = .shared
    var checker = RecipeLinkChecker(timeout: 5)

    /// Nil when no Spoonacular key is configured.
    static func fromConfig(bundle: Bundle = .main) -> SpoonacularMealRecommender? {
        Secrets.value("SPOONACULAR_API_KEY", bundle: bundle).map { SpoonacularMealRecommender(apiKey: $0) }
    }

    func recommend(_ request: MealRequest, avoiding: [String]) async throws -> [MealRecommendation] {
        var search = URLRequest(url: Self.url(for: request))
        search.timeoutInterval = 20
        search.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (data, response) = try await session.data(for: search)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        // 402 is the daily points allowance; 429 is too many requests in a short time.
        if status == 402 || status == 429 { throw MealRecommendationError.limitReached }
        guard status == 200 else { throw MealRecommendationError.badResponse(status) }

        let shown = Set(avoiding.map { $0.lowercased() })
        let recipes = try Self.parse(data).filter {
            !shown.contains($0.title.lowercased()) && DietScreen.passes(request.diet, texts: [$0.title] + $0.ingredients)
        }
        return await withTaskGroup(of: (Int, MealRecommendation).self) { group in
            for (index, recipe) in recipes.enumerated() {
                group.addTask { (index, await meal(from: recipe)) }
            }
            var results: [(Int, MealRecommendation)] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// Links to the original recipe when it still opens, and to the database's page for it otherwise.
    private func meal(from recipe: Recipe) async -> MealRecommendation {
        var link = recipe.page
        if let source = recipe.source {
            // With no database page to fall back on, the original is the only link there is.
            // A site that merely turns the check away still opens in a browser, so its link is kept.
            let opens = recipe.page == nil ? true : await checker.check(source, about: recipe.title) != .missing
            if opens { link = source }
        }
        return MealRecommendation(name: recipe.title, kcal: recipe.kcal, protein: recipe.protein, link: link)
    }

    // MARK: Request

    static func url(for request: MealRequest) -> URL {
        var items = [
            URLQueryItem(name: "number", value: String(asked)),
            URLQueryItem(name: "addRecipeInformation", value: "true"),
            URLQueryItem(name: "addRecipeNutrition", value: "true"),
            URLQueryItem(name: "instructionsRequired", value: "true"),
            URLQueryItem(name: "sort", value: "random"),
            URLQueryItem(name: "type", value: mealType(for: request.slot)),
            URLQueryItem(name: "maxCalories", value: String(request.budget)),
        ]
        if request.slot != .snack {
            items.append(URLQueryItem(name: "minCalories", value: String(request.budget / 3)))
        }
        func add(_ name: String, _ values: [String]) {
            var seen: Set<String> = []
            let unique = values.filter { seen.insert($0).inserted }
            if !unique.isEmpty { items.append(URLQueryItem(name: name, value: unique.joined(separator: ","))) }
        }
        add("diet", request.diet.compactMap(\.spoonacularDiet))
        add("intolerances", request.diet.flatMap(\.spoonacularIntolerances))
        add("excludeIngredients", request.diet.flatMap(\.spoonacularExclusions))

        var components = URLComponents(string: "https://api.spoonacular.com/recipes/complexSearch")!
        components.queryItems = items
        return components.url!
    }

    private static func mealType(for slot: MealSlot) -> String {
        switch slot {
        case .breakfast: "breakfast"
        case .lunch, .dinner: "main course"
        case .snack: "snack"
        }
    }

    // MARK: Response

    private struct Payload: Decodable {
        struct Result: Decodable {
            struct Nutrition: Decodable {
                struct Nutrient: Decodable {
                    var name: String
                    var amount: Double
                }
                struct Ingredient: Decodable { var name: String }
                var nutrients: [Nutrient]
                var ingredients: [Ingredient]?
            }
            var title: String
            var sourceUrl: String?
            var spoonacularSourceUrl: String?
            var nutrition: Nutrition?
        }
        var results: [Result]
    }

    /// Recipes with no title, no calorie figure or no link at all are left out.
    static func parse(_ data: Data) throws -> [Recipe] {
        try JSONDecoder().decode(Payload.self, from: data).results.compactMap { result in
            func amount(_ name: String) -> Int? {
                result.nutrition?.nutrients.first { $0.name == name }.map { Int($0.amount.rounded()) }
            }
            let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let source = secure(result.sourceUrl), page = secure(result.spoonacularSourceUrl)
            guard !title.isEmpty, let kcal = amount("Calories"), kcal > 0, source != nil || page != nil else { return nil }
            return Recipe(
                title: title, kcal: kcal, protein: max(0, amount("Protein") ?? 0),
                ingredients: result.nutrition?.ingredients?.map(\.name) ?? [], source: source, page: page
            )
        }
    }

    /// A web address over HTTPS. Old plain-http addresses are tried over https instead.
    private static func secure(_ text: String?) -> URL? {
        guard let text, var components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.host?.isEmpty == false else { return nil }
        if components.scheme == "http" { components.scheme = "https" }
        return components.scheme == "https" ? components.url : nil
    }
}

private extension UserProfile.Diet {
    var spoonacularDiet: String? {
        switch self {
        case .vegetarian: "vegetarian"
        case .vegan: "vegan"
        case .pescatarian: "pescetarian"
        default: nil
        }
    }

    var spoonacularIntolerances: [String] {
        switch self {
        case .kosher, .shellfishAllergy: ["shellfish"]
        case .glutenFree: ["gluten"]
        case .dairyFree: ["dairy"]
        case .nutAllergy: ["peanut", "tree nut"]
        default: []
        }
    }

    /// The database has no halal or kosher filter, so the parts that come down to an ingredient are excluded by name.
    /// It cannot tell how meat was prepared, or spot meat served with dairy.
    var spoonacularExclusions: [String] {
        switch self {
        case .halal: ["pork", "bacon", "ham", "prosciutto", "lard", "gelatin", "wine", "beer", "rum", "vodka", "bourbon", "brandy"]
        case .kosher: ["pork", "bacon", "ham", "prosciutto", "lard"]
        default: []
        }
    }
}
