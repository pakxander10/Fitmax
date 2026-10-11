import FirebaseAILogic
import Foundation

/// Same job as `GeminiFoodAnalyzer`, but Firebase AI Logic holds the Gemini key, so none ships in the app.
struct FirebaseFoodAnalyzer: FoodAnalyzing {
    private let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
        modelName: GeminiFoodAnalyzer.defaultModel,
        generationConfig: GenerationConfig(responseMIMEType: "application/json", responseSchema: Self.schema)
    )

    func estimate(_ input: FoodInput) async throws -> [FoodItem] {
        let response: GenerateContentResponse
        switch input {
        case .photo(let jpeg):
            response = try await model.generateContent(
                GeminiFoodAnalyzer.prompt,
                GeminiFoodAnalyzer.photoInstruction,
                InlineDataPart(data: jpeg, mimeType: "image/jpeg")
            )
        case .text(let description):
            response = try await model.generateContent(
                GeminiFoodAnalyzer.prompt,
                GeminiFoodAnalyzer.textInstruction(description)
            )
        }
        guard let json = response.text, !json.isEmpty else { throw GeminiFoodAnalyzer.AnalyzerError.noContent }
        return try GeminiFoodAnalyzer.items(fromJSON: json)
    }

    private static let schema = Schema.object(properties: [
        "items": .array(items: .object(
            properties: [
                "name": .string(),
                "grams": .integer(), "kcal": .integer(), "protein": .integer(), "carbs": .integer(), "fat": .integer(),
                "confidence": .enumeration(values: ["low", "medium", "high"]),
                "serving_name": .string(),
                "serving_grams": .double(),
            ],
            // Only foods with a natural serving (an egg, a slice) get these.
            optionalProperties: ["serving_name", "serving_grams"]
        )),
    ])
}
