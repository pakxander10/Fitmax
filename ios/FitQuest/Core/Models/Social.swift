import Foundation

struct Gym: Identifiable, Equatable {
    let id: String
    let name: String
    let logo: String

    var shortName: String { name.components(separatedBy: " · ").first ?? name }
}

/// Anyone who uses the app, friend or not.
struct Member: Identifiable, Equatable {
    var id: String { initials }
    let initials: String
    let name: String
    let gymID: String
    let atGym: Bool
    let level: Int
    let streak: Int
    let since: String?
    let song: String?
    let pet: String
    let week: String
    /// They have chosen to hide their profile from people who are not their friends.
    var isPrivate = false

    var firstName: String { name.components(separatedBy: " ").first ?? name }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || name.localizedStandardContains(trimmed)
    }
}

/// A track trending at a gym, with the member ids behind the numbers.
struct Song: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let artist: String
    let listeningNow: [String]
    let listenedThisWeek: [String]
}

/// Who a song's listeners are, as far as the current user is allowed to see.
struct SongAudience: Equatable {
    var now: [Member]
    var earlier: [Member]
    /// Listeners whose profiles are hidden from non-friends; counted but not named.
    var hiddenCount: Int

    var total: Int { now.count + earlier.count + hiddenCount }
}
