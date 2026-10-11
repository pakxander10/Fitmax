import Foundation

/// Sends a photo to the SAM 3D Body scan worker (backend/worker/server.py) and reads back estimates.
/// The worker only accepts a Firebase ID token, so `idToken` comes from Firebase Auth.
struct WorkerBodyScanner: BodyScanning {
    /// Key in Secrets.plist. The Colab tunnel address changes on every restart, so it is never committed.
    static let urlKey = "SCAN_WORKER_URL"
    /// Longer than the worker's own 80 s model limit, shorter than the tunnel's ~100 s cut-off.
    static let timeout: TimeInterval = 95

    var baseURL: URL
    var idToken: () async throws -> String
    var session: URLSession = .shared

    /// Nil when no worker address is set up, so the app can say scanning is unavailable.
    static func fromConfig(bundle: Bundle = .main, idToken: @escaping () async throws -> String) -> WorkerBodyScanner? {
        guard let text = Secrets.value(urlKey, bundle: bundle),
              let url = URL(string: text), url.scheme == "https" || url.scheme == "http" else { return nil }
        return WorkerBodyScanner(baseURL: url, idToken: idToken)
    }

    func scan(_ request: ScanRequest) async throws -> Biometrics {
        let token: String
        do {
            token = try await idToken()
        } catch {
            throw ScanError.notSignedIn
        }

        let boundary = "FitQuest-\(UUID().uuidString)"
        var http = URLRequest(url: baseURL.appendingPathComponent("scan"))
        http.httpMethod = "POST"
        http.timeoutInterval = Self.timeout
        http.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        http.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        http.httpBody = Self.body(for: request, boundary: boundary)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: http)
        } catch {
            throw ScanError.unavailable
        }
        return try Self.biometrics(status: (response as? HTTPURLResponse)?.statusCode ?? 0, data: data)
    }

    /// Maps the worker's reply to a scan or to the error the person should see.
    static func biometrics(status: Int, data: Data) throws -> Biometrics {
        switch status {
        case 200:
            do {
                return try Biometrics.decoder().decode(Biometrics.self, from: data)
            } catch {
                throw ScanError.unavailable
            }
        case 401:
            throw ScanError.notSignedIn
        case 413:
            throw ScanError.badPhoto
        case 422:
            throw errorCode(in: data) == "no_person" ? ScanError.noPerson : ScanError.badPhoto
        default:
            throw ScanError.unavailable
        }
    }

    private static func errorCode(in data: Data) -> String? {
        struct Reply: Decodable {
            struct Detail: Decodable { let code: String }
            let error: Detail?
        }
        return (try? JSONDecoder().decode(Reply.self, from: data))?.error?.code
    }

    private static func body(for request: ScanRequest, boundary: String) -> Data {
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }

        field("height_cm", String(format: "%.1f", request.heightCm))
        field("sex", request.sex.rawValue)
        if let weightKg = request.weightKg {
            field("weight_kg", String(format: "%.1f", weightKg))
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"scan.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(request.photo)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}
