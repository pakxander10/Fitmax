import XCTest
@testable import FitQuest

final class WorkerBodyScannerTests: XCTestCase {
    private let photo = Data([0xFF, 0xD8, 0xFF, 0x01, 0x02])
    private let request = { (photo: Data) in ScanRequest(photo: photo, heightCm: 175, weightKg: 72.5, sex: .male) }

    override func setUp() {
        ScanStub.reset()
    }

    private func scanner(token: @escaping () async throws -> String = { "firebase-token" }) -> WorkerBodyScanner {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ScanStub.self]
        return WorkerBodyScanner(
            baseURL: URL(string: "https://worker.example.com")!,
            idToken: token,
            session: URLSession(configuration: config)
        )
    }

    private func failure(_ scanner: WorkerBodyScanner) async -> ScanError? {
        do {
            _ = try await scanner.scan(request(photo))
            return nil
        } catch {
            return error as? ScanError
        }
    }

    func testSendsThePhotoAndProfileWithTheFirebaseToken() async throws {
        ScanStub.respond(200, BiometricsTests.workerJSON)
        let scan = try await scanner().scan(request(photo))

        XCTAssertEqual(scan.waistCm, 84.0)
        let sent = try XCTUnwrap(ScanStub.lastRequest)
        XCTAssertEqual(sent.url?.path, "/scan")
        XCTAssertEqual(sent.httpMethod, "POST")
        XCTAssertEqual(sent.value(forHTTPHeaderField: "Authorization"), "Bearer firebase-token")
        let body = String(decoding: ScanStub.lastBody, as: UTF8.self)
        XCTAssertTrue(body.contains("name=\"height_cm\"\r\n\r\n175.0\r\n"))
        XCTAssertTrue(body.contains("name=\"weight_kg\"\r\n\r\n72.5\r\n"))
        XCTAssertTrue(body.contains("name=\"sex\"\r\n\r\nmale\r\n"))
        XCTAssertTrue(body.contains("Content-Type: image/jpeg"))
        XCTAssertNotNil(ScanStub.lastBody.range(of: photo))
    }

    // Colab sleeps and tunnels change; the app must say "try later", never crash.
    func testWorkerDownMeansUnavailable() async {
        ScanStub.respond(503, #"{"fallback":"on_device","error":{"code":"scan_unavailable","message":"x"}}"#)
        let error = await failure(scanner())
        XCTAssertEqual(error, .unavailable)
    }

    func testNetworkFailureMeansUnavailable() async {
        ScanStub.fails = true
        let error = await failure(scanner())
        XCTAssertEqual(error, .unavailable)
    }

    func testNoPersonInThePhoto() async {
        ScanStub.respond(422, #"{"error":{"code":"no_person","message":"x"}}"#)
        let error = await failure(scanner())
        XCTAssertEqual(error, .noPerson)
    }

    func testUnreadableOrHugePhoto() async {
        ScanStub.respond(422, #"{"error":{"code":"bad_photo","message":"x"}}"#)
        let unreadable = await failure(scanner())
        XCTAssertEqual(unreadable, .badPhoto)
        ScanStub.respond(413, #"{"error":{"code":"photo_too_large","message":"x"}}"#)
        let huge = await failure(scanner())
        XCTAssertEqual(huge, .badPhoto)
    }

    func testRejectedTokenAsksToSignInAgain() async {
        ScanStub.respond(401, #"{"error":{"code":"unauthorized","message":"x"}}"#)
        let error = await failure(scanner())
        XCTAssertEqual(error, .notSignedIn)
    }

    func testNoTokenStopsBeforeUploadingThePhoto() async {
        let error = await failure(scanner(token: { throw URLError(.notConnectedToInternet) }))
        XCTAssertEqual(error, .notSignedIn)
        XCTAssertNil(ScanStub.lastRequest)
    }

    func testGarbledReplyMeansUnavailable() async {
        ScanStub.respond(200, "not json")
        let error = await failure(scanner())
        XCTAssertEqual(error, .unavailable)
    }

    func testNoWorkerAddressMeansNoScanner() {
        XCTAssertNil(WorkerBodyScanner.fromConfig(bundle: Bundle(for: Self.self), idToken: { "t" }))
    }
}

/// Answers every request with a canned status and body, and remembers what was sent.
final class ScanStub: URLProtocol {
    static var status = 200
    static var body = Data()
    static var fails = false
    static var lastRequest: URLRequest?
    static var lastBody = Data()

    static func reset() {
        status = 200
        body = Data()
        fails = false
        lastRequest = nil
        lastBody = Data()
    }

    static func respond(_ status: Int, _ json: String) {
        self.status = status
        body = Data(json.utf8)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lastRequest = request
        // URLSession hands protocols the body as a stream, not as httpBody.
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map(Self.read) ?? Data()
        if Self.fails {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
