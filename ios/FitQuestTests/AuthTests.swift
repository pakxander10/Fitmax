import XCTest
@testable import FitQuest

final class AuthTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        suite = "fq-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: Credentials

    func testCredentialProblems() {
        var credentials = Credentials(name: "", email: "alex@example.com", password: "secret1")
        XCTAssertEqual(credentials.problem(for: .signUp), "Enter your name.")
        XCTAssertNil(credentials.problem(for: .signIn), "Sign in does not ask for a name")

        credentials.name = "Alex"
        credentials.email = "alex@example"
        XCTAssertEqual(credentials.problem(for: .signUp), "Enter a valid email address.")
        credentials.email = "not an email@example.com"
        XCTAssertEqual(credentials.problem(for: .signIn), "Enter a valid email address.")

        credentials.email = "  Alex@Example.com "
        credentials.password = "12345"
        XCTAssertEqual(credentials.problem(for: .signUp), "Use a password of at least 6 characters.")
        XCTAssertNil(credentials.problem(for: .signIn), "An existing password is only checked for being there")
        credentials.password = ""
        XCTAssertEqual(credentials.problem(for: .signIn), "Enter your password.")

        credentials.password = "123456"
        XCTAssertNil(credentials.problem(for: .signUp))
    }

    // MARK: On-device accounts

    func testSignUpCreatesAndRemembersTheAccount() async throws {
        let auth = LocalAuthService(defaults: defaults)
        XCTAssertNil(auth.currentAccount)

        let account = try await auth.signUp(name: " Alex Moreno ", email: " Alex@Example.com ", password: "secret1")

        XCTAssertEqual(account.name, "Alex Moreno")
        XCTAssertEqual(account.email, "alex@example.com")
        XCTAssertFalse(account.id.isEmpty)
        XCTAssertEqual(auth.currentAccount, account)
        XCTAssertEqual(LocalAuthService(defaults: defaults).currentAccount, account, "Survives a relaunch")
    }

    func testAnEmailCanOnlyBeRegisteredOnce() async throws {
        let auth = LocalAuthService(defaults: defaults)
        _ = try await auth.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        await assertThrows(.emailInUse) {
            _ = try await auth.signUp(name: "Other Alex", email: "ALEX@example.com", password: "another1")
        }
    }

    func testSignInChecksThePassword() async throws {
        let auth = LocalAuthService(defaults: defaults)
        let created = try await auth.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try auth.signOut()
        XCTAssertNil(auth.currentAccount)

        await assertThrows(.wrongCredentials) { _ = try await auth.signIn(email: "alex@example.com", password: "secret2") }
        await assertThrows(.wrongCredentials) { _ = try await auth.signIn(email: "nobody@example.com", password: "secret1") }
        XCTAssertNil(auth.currentAccount)

        let account = try await auth.signIn(email: "Alex@Example.com", password: "secret1")
        XCTAssertEqual(account, created)
        XCTAssertEqual(auth.currentAccount, created)
    }

    func testSignOutIsRememberedAcrossLaunches() async throws {
        let auth = LocalAuthService(defaults: defaults)
        _ = try await auth.signUp(name: "Alex", email: "alex@example.com", password: "secret1")
        try auth.signOut()
        XCTAssertNil(LocalAuthService(defaults: defaults).currentAccount)
    }

    func testThePasswordItselfIsNeverStored() async throws {
        let auth = LocalAuthService(defaults: defaults)
        _ = try await auth.signUp(name: "Alex", email: "alex@example.com", password: "correct-horse-battery")
        let stored = try XCTUnwrap(defaults.persistentDomain(forName: suite))
        let bytes = try PropertyListSerialization.data(fromPropertyList: stored, format: .xml, options: 0)
        // Data values are base64 in an XML plist, so check both spellings.
        let text = String(decoding: bytes, as: UTF8.self) + stored.values.compactMap { ($0 as? Data).map { String(decoding: $0, as: UTF8.self) } }.joined()
        XCTAssertFalse(text.contains("correct-horse-battery"))
        XCTAssertTrue(text.contains("alex@example.com"), "Sanity check that the account is in there")
    }

    // MARK: Profiles

    func testProfilesAreStoredPerAccount() async throws {
        let store = LocalProfileStore(defaults: defaults)
        let profile = UserProfile(
            sex: .female, age: 30, heightCm: 165, weightKg: 60, goal: .cut, experience: .beginner,
            daysPerWeek: 3, injuries: [.lowerBack], equipment: [.dumbbells]
        )
        let nothing = try await store.profile(for: "a")
        XCTAssertNil(nothing)

        try await store.save(profile, for: "a")

        let loaded = try await LocalProfileStore(defaults: defaults).profile(for: "a")
        XCTAssertEqual(loaded, profile)
        let other = try await store.profile(for: "b")
        XCTAssertNil(other)
    }

    private func assertThrows(_ expected: AuthError, file: StaticString = #filePath, line: UInt = #line, _ work: () async throws -> Void) async {
        do {
            try await work()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? AuthError, expected, file: file, line: line)
        }
    }
}
