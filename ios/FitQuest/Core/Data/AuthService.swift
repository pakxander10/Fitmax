import CryptoKit
import Foundation

/// Sign-up, sign-in and the remembered session. The app only talks to this protocol, so
/// Firebase Auth drops in as a second conformance (`createUser`, `signIn`, `currentUser`, `signOut`).
protocol AuthProviding {
    /// Whoever was signed in last time, without a network call.
    var currentAccount: Account? { get }
    func signUp(name: String, email: String, password: String) async throws -> Account
    func signIn(email: String, password: String) async throws -> Account
    func signOut() throws
}

enum AuthError: Error, Equatable {
    case invalidEmail, weakPassword, emailInUse, wrongCredentials, network, unknown

    /// What to tell the person. Unknown emails and wrong passwords read the same on purpose,
    /// so the login screen cannot be used to find out who has an account.
    var message: String {
        switch self {
        case .invalidEmail: "Enter a valid email address."
        case .weakPassword: "Use a password of at least 6 characters."
        case .emailInUse: "That email already has an account. Sign in instead."
        case .wrongCredentials: "That email and password don’t match an account."
        case .network: "Can’t reach the server. Check your connection and try again."
        case .unknown: "Something went wrong. Try again."
        }
    }
}

enum AuthMode: Equatable {
    case signIn, signUp
}

/// The login form as typed.
struct Credentials: Equatable {
    static let minPasswordLength = 6

    var name = ""
    var email = ""
    var password = ""

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var normalizedEmail: String { Self.normalize(email) }

    /// The first thing wrong with the form, top field first. Nil when it can be sent.
    func problem(for mode: AuthMode) -> String? {
        if mode == .signUp, trimmedName.isEmpty { return "Enter your name." }
        if !Self.looksLikeEmail(normalizedEmail) { return AuthError.invalidEmail.message }
        switch mode {
        case .signUp: return password.count < Self.minPasswordLength ? AuthError.weakPassword.message : nil
        case .signIn: return password.isEmpty ? "Enter your password." : nil
        }
    }

    static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// One "@", no spaces, and a dot somewhere in the domain. The server has the final say.
    static func looksLikeEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !email.contains(where: \.isWhitespace) else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }
}

/// Accounts kept on this phone only, standing in until Firebase Auth is wired up.
/// Passwords are stored as a salted hash, which is enough for a stand-in and not for release.
final class LocalAuthService: AuthProviding {
    private struct Record: Codable {
        var account: Account
        var salt: Data
        var hash: Data
    }

    private static let recordsKey = "fq-auth-accounts"
    private static let currentKey = "fq-auth-current"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentAccount: Account? {
        defaults.string(forKey: Self.currentKey).flatMap { records[$0]?.account }
    }

    func signUp(name: String, email: String, password: String) async throws -> Account {
        let email = Credentials.normalize(email)
        guard Credentials.looksLikeEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= Credentials.minPasswordLength else { throw AuthError.weakPassword }
        var records = records
        guard records[email] == nil else { throw AuthError.emailInUse }

        let account = Account(id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: email)
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        records[email] = Record(account: account, salt: salt, hash: Self.hash(password, salt: salt))
        self.records = records
        defaults.set(email, forKey: Self.currentKey)
        return account
    }

    func signIn(email: String, password: String) async throws -> Account {
        let email = Credentials.normalize(email)
        guard let record = records[email], Self.hash(password, salt: record.salt) == record.hash else {
            throw AuthError.wrongCredentials
        }
        defaults.set(email, forKey: Self.currentKey)
        return record.account
    }

    func signOut() throws {
        defaults.removeObject(forKey: Self.currentKey)
    }

    /// Every account on this phone, keyed by email.
    private var records: [String: Record] {
        get {
            defaults.data(forKey: Self.recordsKey).flatMap { try? JSONDecoder().decode([String: Record].self, from: $0) } ?? [:]
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.recordsKey)
        }
    }

    private static func hash(_ password: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(password.utf8)))
    }
}
