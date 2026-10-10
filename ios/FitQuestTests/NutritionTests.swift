import XCTest
@testable import FitQuest

final class NutritionTests: XCTestCase {
    func testTotalSumsEveryMacro() {
        let total = [
            Macros(kcal: 380, protein: 24, carbs: 52, fat: 9),
            Macros(kcal: 620, protein: 48, carbs: 70, fat: 14),
        ].total
        XCTAssertEqual(total, Macros(kcal: 1_000, protein: 72, carbs: 122, fat: 23))
    }

    func testFoodItemScalesWithGrams() {
        var chicken = FoodItem(
            name: "Grilled chicken breast", grams: 150,
            base: Macros(kcal: 248, protein: 46, carbs: 0, fat: 5), confidence: .medium
        )
        XCTAssertEqual(chicken.macros.kcal, 248)
        chicken.adjust(by: 10)
        XCTAssertEqual(chicken.grams, 160)
        XCTAssertEqual(chicken.macros, Macros(kcal: 265, protein: 49, carbs: 0, fat: 5))
    }

    func testFoodItemNeverDropsBelowTenGrams() {
        var toast = FoodItem(
            name: "Toast", grams: 20,
            base: Macros(kcal: 50, protein: 2, carbs: 9, fat: 1), confidence: .high
        )
        toast.adjust(by: -10)
        toast.adjust(by: -10)
        XCTAssertEqual(toast.grams, 10)
    }

    func testCalorieGoalIsMetWithinTenPercent() {
        XCTAssertTrue(Nutrition.calorieGoalMet(consumed: 1_800, target: 2_000))
        XCTAssertTrue(Nutrition.calorieGoalMet(consumed: 2_200, target: 2_000))
        XCTAssertFalse(Nutrition.calorieGoalMet(consumed: 1_799, target: 2_000))
        XCTAssertFalse(Nutrition.calorieGoalMet(consumed: 2_201, target: 2_000))
    }

    func testMoodCategory() {
        // On track: the workout is done, or calories landed on target.
        XCTAssertEqual(Nutrition.mood(consumedKcal: 600, targetKcal: 2_000, workoutDone: true), .happy)
        XCTAssertEqual(Nutrition.mood(consumedKcal: 1_900, targetKcal: 2_000, workoutDone: false), .happy)
        // Mid-day, nothing wrong yet.
        XCTAssertEqual(Nutrition.mood(consumedKcal: 1_200, targetKcal: 2_000, workoutDone: false), .neutral)
        XCTAssertEqual(Nutrition.mood(consumedKcal: 2_300, targetKcal: 2_000, workoutDone: false), .neutral)
        // Barely eaten, or well over budget.
        XCTAssertEqual(Nutrition.mood(consumedKcal: 600, targetKcal: 2_000, workoutDone: false), .moody)
        XCTAssertEqual(Nutrition.mood(consumedKcal: 2_400, targetKcal: 2_000, workoutDone: false), .moody)
    }

    func testEveryMoodHasItsOwnPoolOfEmoji() {
        var seen: Set<String> = []
        for mood in Mood.allCases {
            XCTAssertGreaterThan(mood.emojis.count, 3, "\(mood)")
            XCTAssertEqual(Set(mood.emojis).count, mood.emojis.count, "\(mood) repeats an emoji")
            XCTAssertTrue(seen.isDisjoint(with: mood.emojis), "\(mood) shares an emoji with another mood")
            seen.formUnion(mood.emojis)
        }
    }

    func testRandomEmojiStaysInTheMoodAndVaries() {
        var generator = SystemRandomNumberGenerator()
        for mood in Mood.allCases {
            var last: String?
            var drawn: Set<String> = []
            for _ in 0..<200 {
                let emoji = mood.randomEmoji(excluding: last, using: &generator)
                XCTAssertTrue(mood.emojis.contains(emoji))
                XCTAssertNotEqual(emoji, last, "the same face should never show twice in a row")
                drawn.insert(emoji)
                last = emoji
            }
            XCTAssertEqual(drawn, Set(mood.emojis), "\(mood) never showed some of its faces")
        }
    }
}
