import Foundation

enum XPEvent {
    case mealLogged, workoutCompleted

    var xp: Int {
        switch self {
        case .mealLogged: 10
        case .workoutCompleted: 100
        }
    }
}

/// XP and the pet level it buys. Level is `floor(sqrt(xp / 50))`, so level N starts at 50·N² XP.
struct GameState: Equatable {
    var xp: Int
    var streakDays = 0

    var level: Int { Int((Double(max(0, xp)) / 50).squareRoot()) }
    var xpToNextLevel: Int { Self.xpRequired(forLevel: level + 1) - xp }

    /// Fraction of the way from the current level's threshold to the next one.
    var progress: Double {
        let floor = Self.xpRequired(forLevel: level)
        let span = Self.xpRequired(forLevel: level + 1) - floor
        return min(1, max(0, Double(xp - floor) / Double(span)))
    }

    static func xpRequired(forLevel level: Int) -> Int { 50 * level * level }

    /// Days in a row with something logged, ending today. Today is not over, so a streak that ran
    /// through yesterday still counts until the day ends.
    static func streak(activeDays: Set<Day>, today: Day) -> Int {
        var day = activeDays.contains(today) ? today : today.adding(-1)
        var count = 0
        while activeDays.contains(day) {
            count += 1
            day = day.adding(-1)
        }
        return count
    }
}
