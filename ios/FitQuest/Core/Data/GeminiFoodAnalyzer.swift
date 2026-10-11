import Foundation

/// Estimates foods from a meal photo or typed description by calling the Gemini API directly.
/// Legacy: the app uses `FirebaseFoodAnalyzer` when Firebase is configured, and this only as a fallback.
struct GeminiFoodAnalyzer: FoodAnalyzing {
    typealias AnalyzerError = GeminiClient.ClientError

    /// The one place the Gemini model is named. The Firebase analyzer and the REST client both read it.
    static let defaultModel = "gemini-3.8-flash"
    /// Tried in order by the REST client when `defaultModel` is out of quota: the free tier counts each model separately.
    static let fallbackModels = ["gemini-3.7-flash", "gemini-3.6-flash"]

    var client: GeminiClient

    init(client: GeminiClient) {
        self.client = client
    }

    init(apiKey: String, session: URLSession = .shared, retryDelay: Duration = .milliseconds(800)) {
        client = GeminiClient(apiKey: apiKey, session: session, retryDelay: retryDelay)
    }

    /// Nil when no Gemini key is configured.
    static func fromConfig(bundle: Bundle = .main) -> GeminiFoodAnalyzer? {
        GeminiClient.fromConfig(bundle: bundle).map(GeminiFoodAnalyzer.init(client:))
    }

    func estimate(_ input: FoodInput) async throws -> [FoodItem] {
        try Self.parse(try await client.send(Self.body(for: input)))
    }

    // MARK: Request

    static func body(for input: FoodInput) -> [String: Any] {
        var parts: [[String: Any]]
        switch input {
        case .photo(let jpeg):
            parts = [
                ["text": photoInstruction],
                ["inline_data": ["mime_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
            ]
        case .text(let description):
            parts = [["text": textInstruction(description)]]
        }
        parts.insert(["text": prompt], at: 0)

        let number: [String: Any] = ["type": "INTEGER"]
        return [
            "contents": [["parts": parts]],
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
                                "grams": number, "kcal": number, "protein": number, "carbs": number, "fat": number,
                                "confidence": ["type": "STRING", "enum": ["low", "medium", "high"]],
                                // Optional: only for foods with a natural serving.
                                "serving_name": ["type": "STRING"],
                                "serving_grams": ["type": "NUMBER"],
                            ],
                            "required": ["name", "grams", "kcal", "protein", "carbs", "fat", "confidence"],
                        ],
                    ]],
                    "required": ["items"],
                ],
            ],
        ]
    }

    static let photoInstruction = "Identify every distinct food or drink in this photo."

    static func textInstruction(_ description: String) -> String {
        "Identify every distinct food or drink in this description: \(description)"
    }

    static let prompt = """
    You are a nutrition estimator. For each food, estimate the portion in grams and the calories and \
    macros (protein, carbs, fat in grams) for that whole portion, not per 100 g. Use a short plain name. \
    Set confidence to low when the portion or food is hard to judge. If there is no food, return an empty items list. \
    When a food has a natural countable or household serving (an egg, a slice, a cup, a tablespoon, a piece), \
    also give serving_name as one singular word and serving_grams as the weight of one serving. \
    Leave both out for foods with no natural serving.
    """

    // MARK: Response

    private struct Payload: Decodable {
        struct Item: Decodable {
            var name: String
            var grams: Int
            var kcal: Int
            var protein: Int
            var carbs: Int
            var fat: Int
            var confidence: String
            var serving_name: String?
            var serving_grams: Double?

            /// A serving only when Gemini gave both a usable name and a positive weight.
            var serving: Serving? {
                guard let grams = serving_grams, grams > 0, var name = serving_name?.trimmingCharacters(in: .whitespaces).lowercased() else { return nil }
                if name.hasPrefix("1 ") { name.removeFirst(2) }
                return name.isEmpty ? nil : Serving(name: name, grams: grams)
            }
        }
        var items: [Item]
    }

    static func parse(_ data: Data) throws -> [FoodItem] {
        try items(fromJSON: try GeminiClient.text(from: data))
    }

    /// Validates Gemini's `{"items": [...]}` JSON text and turns it into foods, dropping empty portions.
    static func items(fromJSON text: String) throws -> [FoodItem] {
        let payload = try JSONDecoder().decode(Payload.self, from: Data(text.utf8))
        return payload.items.filter { $0.grams > 0 }.map {
            FoodItem(
                name: $0.name,
                grams: Double($0.grams),
                base: Macros(kcal: $0.kcal, protein: $0.protein, carbs: $0.carbs, fat: $0.fat),
                confidence: FoodItem.Confidence(rawValue: $0.confidence.lowercased()) ?? .low,
                serving: $0.serving
            )
        }
    }
}
