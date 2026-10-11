import Foundation

/// What a person has earned and done: XP, finished workouts, best lifts and friends.
/// A new account starts with all of it empty.
struct SavedProgress: Codable, Equatable {
    var xp = 0
    var sessions: [WorkoutSession] = []
    /// The top set of each exercise in the last workout that included it, by exercise id ("185 × 8").
    var records: [String: String] = [:]
    var friendIDs: Set<String> = []
    var requestedIDs: Set<String> = []
}

/// Where progress is kept between launches. Firestore can drop in as a second conformance (`users/{uid}`).
protocol ProgressStoring {
    /// An account with nothing saved yet gets empty progress.
    func progress(for accountID: String) async throws -> SavedProgress
    func save(_ progress: SavedProgress, for accountID: String) async throws
}

/// Progress kept on this phone, like `LocalMealStore`.
final class LocalProgressStore: ProgressStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func progress(for accountID: String) async throws -> SavedProgress {
        guard let data = defaults.data(forKey: Self.key(accountID)) else { return SavedProgress() }
        return try JSONDecoder().decode(SavedProgress.self, from: data)
    }

    func save(_ progress: SavedProgress, for accountID: String) async throws {
        defaults.set(try JSONEncoder().encode(progress), forKey: Self.key(accountID))
    }

    private static func key(_ accountID: String) -> String { "fq-progress-\(accountID)" }
}
