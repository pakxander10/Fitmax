import Foundation

/// Where a person's onboarding answers live. Firestore drops in as a second conformance
/// (one `users/{accountID}` document, in the shape `UserProfile` encodes to).
protocol ProfileStoring {
    /// Nil means this account has not finished onboarding. A failed load must throw instead,
    /// or a network blip would send someone through onboarding again and overwrite their profile.
    func profile(for accountID: String) async throws -> UserProfile?
    func save(_ profile: UserProfile, for accountID: String) async throws
}

/// Profiles kept on this phone only, standing in until Firestore is wired up.
final class LocalProfileStore: ProfileStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func profile(for accountID: String) async throws -> UserProfile? {
        guard let data = defaults.data(forKey: Self.key(accountID)) else { return nil }
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    func save(_ profile: UserProfile, for accountID: String) async throws {
        defaults.set(try JSONEncoder().encode(profile), forKey: Self.key(accountID))
    }

    private static func key(_ accountID: String) -> String { "fq-profile-\(accountID)" }
}
