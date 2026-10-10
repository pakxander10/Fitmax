import Foundation

struct Gym: Identifiable, Equatable {
    let id: String
    let name: String
    let logo: String
    let friendsHere: Int

    var shortName: String { name.components(separatedBy: " · ").first ?? name }
}

struct Song: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let artist: String
    let listeners: [String]
    let more: Int
}

struct Friend: Identifiable, Equatable {
    var id: String { initials }
    let initials: String
    let name: String
    let gymID: String
    let atGym: Bool
    let rank: HunterRank
    let level: Int
    let streak: Int
    let since: String?
    let song: String?
    let pet: String
    let week: String

    var firstName: String { name.components(separatedBy: " ").first ?? name }
}
