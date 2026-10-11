import XCTest
@testable import FitQuest

final class TargetCalculatorTests: XCTestCase {
    private func profile(
        sex: UserProfile.Sex = .male, age: Int = 24, heightCm: Double = 178, weightKg: Double = 74.5,
        goal: UserProfile.Goal = .leanBulk, days: Int = 4
    ) -> UserProfile {
        UserProfile(
            sex: sex, age: age, heightCm: heightCm, weightKg: weightKg, goal: goal,
            experience: .intermediate, daysPerWeek: days, injuries: [], equipment: []
        )
    }

    // MARK: Mifflin-St Jeor

    func testBMROnKnownInputs() {
        XCTAssertEqual(TargetCalculator.bmr(for: profile()), 1_742.5, accuracy: 0.001)
        XCTAssertEqual(TargetCalculator.bmr(for: profile(sex: .female, age: 30, heightCm: 165, weightKg: 60)), 1_320.25, accuracy: 0.001)
    }

    func testActivityFactorFollowsTrainingDays() {
        XCTAssertEqual(TargetCalculator.activityFactor(daysPerWeek: 0), 1.2)
        XCTAssertEqual(TargetCalculator.activityFactor(daysPerWeek: 1), 1.375)
        XCTAssertEqual(TargetCalculator.activityFactor(daysPerWeek: 2), 1.375)
        XCTAssertEqual(TargetCalculator.activityFactor(daysPerWeek: 3), 1.55)
        XCTAssertEqual(TargetCalculator.activityFactor(daysPerWeek: 5), 1.55)
        XCTAssertEqual(TargetCalculator.activityFactor(daysPerWeek: 6), 1.725)
        XCTAssertEqual(TargetCalculator.activityFactor(daysPerWeek: 7), 1.725)
    }

    // MARK: Calories

    func testLeanBulkAddsASmallSurplus() {
        // 1742.5 × 1.55 = 2700.9, + 250, rounded to the nearest 10.
        XCTAssertEqual(TargetCalculator.targets(for: profile()).kcal, 2_950)
    }

    func testMaintainIsMaintenance() {
        XCTAssertEqual(TargetCalculator.targets(for: profile(goal: .maintain)).kcal, 2_700)
    }

    func testCutDeficitIsCappedAt500() {
        // A fifth of 2700.9 would be 540; the cap holds it to 500.
        XCTAssertEqual(TargetCalculator.targets(for: profile(goal: .cut)).kcal, 2_200)
    }

    func testCutDeficitIsAFifthForSmallerEaters() {
        // 1320.25 × 1.375 = 1815.3, minus a fifth = 1452.3.
        let small = profile(sex: .female, age: 30, heightCm: 165, weightKg: 60, goal: .cut, days: 2)
        XCTAssertEqual(TargetCalculator.targets(for: small).kcal, 1_450)
    }

    func testCaloriesNeverDropBelowTheFloor() {
        let woman = profile(sex: .female, age: 45, heightCm: 150, weightKg: 45, goal: .cut, days: 1)
        XCTAssertEqual(TargetCalculator.targets(for: woman).kcal, 1_200)
        let man = profile(sex: .male, age: 60, heightCm: 160, weightKg: 50, goal: .cut, days: 1)
        XCTAssertEqual(TargetCalculator.targets(for: man).kcal, 1_500)
    }

    // Project safety rule: a target is never below what the body burns at rest.
    func testCaloriesNeverDropBelowBMR() {
        // Sedentary, so a fifth off maintenance (1.2 × BMR) would land at 0.96 × BMR.
        let sedentary = profile(weightKg: 110, goal: .cut, days: 0)
        let bmr = TargetCalculator.bmr(for: sedentary)
        XCTAssertGreaterThan(bmr, 1_500, "Above the hard floor, so the BMR clamp is what is being tested")
        XCTAssertGreaterThanOrEqual(Double(TargetCalculator.targets(for: sedentary).kcal), bmr)
    }

    // MARK: Macros

    func testMacrosForTheLeanBulk() {
        let targets = TargetCalculator.targets(for: profile())
        XCTAssertEqual(targets.protein, 149) // 2.0 g per kg
        XCTAssertEqual(targets.fat, 82) // a quarter of calories
        XCTAssertEqual(targets.carbs, 404) // whatever calories are left
    }

    func testProteinIsHigherOnACut() {
        XCTAssertEqual(TargetCalculator.targets(for: profile(goal: .cut)).protein, 164) // 2.2 g per kg
        XCTAssertEqual(TargetCalculator.targets(for: profile(goal: .maintain)).protein, 134) // 1.8 g per kg
    }

    func testMacrosAddUpToTheCalorieTargetForEveryProfile() {
        for sex in UserProfile.Sex.allCases {
            for goal in UserProfile.Goal.allCases {
                for weight in stride(from: 40.0, through: 200.0, by: 20) {
                    for days in [1, 4, 7] {
                        let targets = TargetCalculator.targets(for: profile(sex: sex, weightKg: weight, goal: goal, days: days))
                        let fromMacros = targets.protein * 4 + targets.carbs * 4 + targets.fat * 9
                        XCTAssertGreaterThanOrEqual(targets.carbs, 0)
                        XCTAssertEqual(Double(fromMacros), Double(targets.kcal), accuracy: 12, "\(sex) \(goal) \(weight) kg \(days) days")
                    }
                }
            }
        }
    }
}
