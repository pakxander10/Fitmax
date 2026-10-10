import Foundation

/// Hunter Rank thresholds from PROJECT_CONTEXT §11.2. The backend's `services/xp.py` is the
/// source of truth once it exists; this mirror only drives the UI until `/v1/dashboard` is wired.
enum HunterRank: String, CaseIterable {
    case e = "E", d = "D", c = "C", b = "B", a = "A", s = "S"

    var threshold: Int {
        switch self {
        case .e: 0
        case .d: 500
        case .c: 1_500
        case .b: 3_500
        case .a: 7_000
        case .s: 12_000
        }
    }

    var next: HunterRank? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    static func forXP(_ xp: Int) -> HunterRank {
        allCases.last { xp >= $0.threshold } ?? .e
    }
}

enum XPEvent {
    case mealLogged, workoutCompleted

    var xp: Int {
        switch self {
        case .mealLogged: 10
        case .workoutCompleted: 100
        }
    }
}

struct GameState: Equatable {
    var xp: Int
    var streakDays = 0

    var rank: HunterRank { .forXP(xp) }
    var nextRank: HunterRank? { rank.next }
    var level: Int { Int((Double(max(0, xp)) / 50).squareRoot()) }

    var xpToNext: Int {
        guard let nextRank else { return 0 }
        return nextRank.threshold - xp
    }

    /// Fraction of the way from the current rank's threshold to the next one.
    var progress: Double {
        guard let nextRank else { return 1 }
        let span = Double(nextRank.threshold - rank.threshold)
        return min(1, max(0, Double(xp - rank.threshold) / span))
    }
}
