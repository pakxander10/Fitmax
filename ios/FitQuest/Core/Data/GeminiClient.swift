import Foundation

/// One Gemini `generateContent` call that answers in JSON, shared by everything that asks Gemini for something.
///
/// The key ships inside the app bundle, so this is for demos only. For release, send these
/// requests through a backend that holds the key.
struct GeminiClient {
    enum ClientError: Error { case badResponse(Int), noContent }

    var apiKey: String
    var model = GeminiFoodAnalyzer.defaultModel
    /// Tried in order when `model` has used up its quota.
    var fallbackModels = GeminiFoodAnalyzer.fallbackModels
    var session: URLSession = .shared
    /// Wait before the first retry; the second waits twice as long.
    var retryDelay: Duration = .milliseconds(800)

    private static let maxAttempts = 3
    /// Statuses that mean "busy, try again", not "your request is wrong".
    private static let transientStatuses: Set<Int> = [500, 502, 503, 504]
    /// "Too many requests": the quota for this model is used up, for the minute or for the day.
    static let quotaStatus = 429

    /// Nil when no Gemini key is configured.
    static func fromConfig(bundle: Bundle = .main) -> GeminiClient? {
        Secrets.value("GEMINI_API_KEY", bundle: bundle).map { GeminiClient(apiKey: $0) }
    }

    /// Sends a request body and returns the raw response, retrying while the service is busy
    /// and moving to the next model when one is out of quota.
    func send(_ body: [String: Any]) async throws -> Data {
        var status = 0
        for model in [model] + fallbackModels {
            let (data, modelStatus) = try await send(body, to: model)
            if let data { return data }
            status = modelStatus
            guard status == Self.quotaStatus else { break }
        }
        throw ClientError.badResponse(status)
    }

    /// The response from one model, or nil with the status that ended the attempts.
    private func send(_ body: [String: Any], to model: String) async throws -> (Data?, Int) {
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        var status = 0
        for attempt in 0..<Self.maxAttempts {
            if attempt > 0 { try await Task.sleep(for: retryDelay * attempt) }
            let (data, response) = try await session.data(for: request)
            status = (response as? HTTPURLResponse)?.statusCode ?? 200
            if status == 200 { return (data, status) }
            guard Self.transientStatuses.contains(status) else { break }
        }
        return (nil, status)
    }

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

    /// The text the model wrote, out of Gemini's response envelope.
    static func text(from data: Data) throws -> String {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let text = envelope.candidates?.first?.content?.parts?.compactMap(\.text).joined(),
              !text.isEmpty else { throw ClientError.noContent }
        return text
    }

    /// Unwraps the JSON the model wrote from Gemini's response envelope and decodes it.
    static func decode<Payload: Decodable>(_ type: Payload.Type, from data: Data) throws -> Payload {
        try JSONDecoder().decode(type, from: Data(try text(from: data).utf8))
    }
}
