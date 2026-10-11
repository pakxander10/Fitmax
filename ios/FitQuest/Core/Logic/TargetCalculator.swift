import Foundation

/// Daily calorie and macro targets from a profile. Plain arithmetic, so the numbers never come from an AI.
enum TargetCalculator {
    /// Most a cut may take off maintenance, in kcal.
    static let maxDeficit = 500.0
    static let leanBulkSurplus = 250.0

    /// Resting energy use, Mifflin-St Jeor.
    static func bmr(for profile: UserProfile) -> Double {
        10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.age) + (profile.sex == .male ? 5 : -161)
    }

    /// The standard activity multipliers, chosen by training days a week.
    static func activityFactor(daysPerWeek: Int) -> Double {
        switch daysPerWeek {
        case ..<1: 1.2
        case 1...2: 1.375
        case 3...5: 1.55
        default: 1.725
        }
    }

    static func maintenance(for profile: UserProfile) -> Double {
        bmr(for: profile) * activityFactor(daysPerWeek: profile.daysPerWeek)
    }

    static func targets(for profile: UserProfile) -> Targets {
        let maintenance = maintenance(for: profile)
        let goalKcal: Double = switch profile.goal {
        case .cut: maintenance - min(maxDeficit, maintenance * 0.2)
        case .maintain: maintenance
        case .leanBulk: maintenance + leanBulkSurplus
        }
        // Rounded to the nearest 10, and never below a safe minimum.
        let floor = profile.sex == .male ? 1_500.0 : 1_200.0
        let kcal = max(floor, (goalKcal / 10).rounded() * 10)

        let proteinPerKg: Double = switch profile.goal {
        case .cut: 2.2
        case .maintain: 1.8
        case .leanBulk: 2.0
        }
        // Capped at 35% of calories so heavier people are not handed an impossible protein figure.
        let protein = min(proteinPerKg * profile.weightKg, kcal * 0.35 / 4).rounded()
        let fat = (kcal * 0.25 / 9).rounded()
        let carbs = max(0, (kcal - protein * 4 - fat * 9) / 4).rounded()
        return Targets(kcal: Int(kcal), protein: Int(protein), carbs: Int(carbs), fat: Int(fat))
    }
}
