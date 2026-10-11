import Foundation

/// Where scan results live. Only the numbers are stored, never the photo.
/// Firestore drops in as a second conformance (`users/{accountID}/biometrics`).
protocol BiometricsStoring {
    func latest(for accountID: String) async throws -> Biometrics?
    func save(_ biometrics: Biometrics, for accountID: String) async throws
}

/// The latest scan kept on this phone, standing in until Firestore is wired up (like `LocalProfileStore`).
final class LocalBiometricsStore: BiometricsStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func latest(for accountID: String) async throws -> Biometrics? {
        guard let data = defaults.data(forKey: Self.key(accountID)) else { return nil }
        return try Biometrics.decoder().decode(Biometrics.self, from: data)
    }

    func save(_ biometrics: Biometrics, for accountID: String) async throws {
        defaults.set(try Biometrics.encoder().encode(biometrics), forKey: Self.key(accountID))
    }

    private static func key(_ accountID: String) -> String { "fq-biometrics-\(accountID)" }
}
