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

enum Mood: String {
    case happy, hungry, sad, proud

    var label: String { rawValue.uppercased() }
}

enum Nutrition {
    /// A day counts as on-target when intake lands within ±10% of the calorie target.
    static func calorieGoalMet(consumed: Int, target: Int) -> Bool {
        abs(consumed - target) * 10 <= target
    }

    static func mood(consumedKcal: Int, targetKcal: Int, workoutDone: Bool) -> Mood {
        if workoutDone, calorieGoalMet(consumed: consumedKcal, target: targetKcal) { return .proud }
        return consumedKcal * 2 < targetKcal ? .hungry : .happy
    }
}
