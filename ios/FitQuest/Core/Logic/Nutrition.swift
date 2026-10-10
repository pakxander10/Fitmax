import Foundation

struct Macros: Equatable {
    var kcal = 0
    var protein = 0
    var carbs = 0
    var fat = 0

    static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein, carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat)
    }

    func scaled(by factor: Double) -> Macros {
        func scale(_ value: Int) -> Int { Int((Double(value) * factor).rounded()) }
        return Macros(kcal: scale(kcal), protein: scale(protein), carbs: scale(carbs), fat: scale(fat))
    }
}

extension Sequence where Element == Macros {
    var total: Macros { reduce(Macros(), +) }
}

struct Targets: Equatable {
    var kcal = 2_000
    var protein = 150
    var carbs = 220
    var fat = 60
}

/// How the pet feels about the day. Each mood shows as one of several emoji, picked at random.
enum Mood: String, CaseIterable {
    case happy, neutral, moody

    var emojis: [String] {
        switch self {
        case .happy: ["😀", "😄", "😁", "😊", "🥰", "😎", "🤩", "😋", "🥳"]
        case .neutral: ["🙂", "😐", "😶", "🤔", "😌", "🥱", "😴", "🫤"]
        case .moody: ["😔", "😢", "😞", "🥺", "😩", "😤", "😒", "🙄"]
        }
    }

    /// A face from this mood's pool, never the one just shown.
    func randomEmoji<G: RandomNumberGenerator>(excluding last: String? = nil, using generator: inout G) -> String {
        let pool = emojis.filter { $0 != last }
        return pool.randomElement(using: &generator) ?? emojis[0]
    }

    func randomEmoji(excluding last: String? = nil) -> String {
        var generator = SystemRandomNumberGenerator()
        return randomEmoji(excluding: last, using: &generator)
    }
}

enum Nutrition {
    /// A day counts as on-target when intake lands within ±10% of the calorie target.
    static func calorieGoalMet(consumed: Int, target: Int) -> Bool {
        abs(consumed - target) * 10 <= target
    }

    /// Happy once the workout is done or calories are on target; moody when the day has gone
    /// badly wrong (under half the target, or more than 15% over); otherwise neutral.
    static func mood(consumedKcal: Int, targetKcal: Int, workoutDone: Bool) -> Mood {
        if workoutDone || calorieGoalMet(consumed: consumedKcal, target: targetKcal) { return .happy }
        if consumedKcal * 2 < targetKcal || consumedKcal * 100 > targetKcal * 115 { return .moody }
        return .neutral
    }
}
