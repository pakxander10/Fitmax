import Foundation

/// Estimates foods from a meal photo or typed description with the Gemini API.
///
/// The key ships inside the app bundle, so this is for demos only. For release, point `endpoint`
/// at a backend that holds the key (the `/v1/food/*` seam this protocol was written for).
struct GeminiFoodAnalyzer: FoodAnalyzing {
    enum AnalyzerError: Error { case badResponse(Int), noContent }

    var apiKey: String
    var model = "gemini-3.8-flash"
    var session: URLSession = .shared

    /// Reads `GEMINI_API_KEY` from the environment, then from a gitignored `Secrets.plist` in the bundle.
    static func fromConfig(bundle: Bundle = .main) -> GeminiFoodAnalyzer? {
        var key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        if key?.isEmpty != false,
           let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) {
            key = dict["GEMINI_API_KEY"] as? String
        }
        guard let key, !key.isEmpty, key != "paste-your-key-here" else { return nil }
        return GeminiFoodAnalyzer(apiKey: key)
    }

    func estimate(_ input: FoodInput) async throws -> [FoodItem] {
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.body(for: input))

        let (data, response) = try await session.data(for: request)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw AnalyzerError.badResponse(status)
        }
        return try Self.parse(data)
    }

    // MARK: Request

    static func body(for input: FoodInput) -> [String: Any] {
        var parts: [[String: Any]]
        switch input {
        case .photo(let jpeg):
            parts = [
                ["text": "Identify every distinct food or drink in this photo."],
                ["inline_data": ["mime_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
            ]
        case .text(let description):
            parts = [["text": "Identify every distinct food or drink in this description: \(description)"]]
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
                            ],
                            "required": ["name", "grams", "kcal", "protein", "carbs", "fat", "confidence"],
                        ],
                    ]],
                    "required": ["items"],
                ],
            ],
        ]
    }

    private static let prompt = """
    You are a nutrition estimator. For each food, estimate the portion in grams and the calories and \
    macros (protein, carbs, fat in grams) for that whole portion, not per 100 g. Use a short plain name. \
    Set confidence to low when the portion or food is hard to judge. If there is no food, return an empty items list.
    """

    // MARK: Response

    private struct Envelope: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { var text: String? }
                var parts: [Part]?
            }
            var content: Content?
        }
        var candidates: [Candidate]?
    }

    private struct Payload: Decodable {
        struct Item: Decodable {
            var name: String
            var grams: Int
            var kcal: Int
            var protein: Int
            var carbs: Int
            var fat: Int
            var confidence: String
        }
        var items: [Item]
    }

    static func parse(_ data: Data) throws -> [FoodItem] {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let text = envelope.candidates?.first?.content?.parts?.compactMap(\.text).joined(),
              !text.isEmpty else { throw AnalyzerError.noContent }
        let payload = try JSONDecoder().decode(Payload.self, from: Data(text.utf8))
        return payload.items.filter { $0.grams > 0 }.map {
            FoodItem(
                name: $0.name,
                grams: $0.grams,
                base: Macros(kcal: $0.kcal, protein: $0.protein, carbs: $0.carbs, fat: $0.fat),
                confidence: FoodItem.Confidence(rawValue: $0.confidence.lowercased()) ?? .low
            )
        }
    }
}
