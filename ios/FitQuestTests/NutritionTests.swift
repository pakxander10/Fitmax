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
        chicken.step(1)
        XCTAssertEqual(chicken.grams, 160)
        XCTAssertEqual(chicken.macros, Macros(kcal: 265, protein: 49, carbs: 0, fat: 5))
    }

    func testFoodItemNeverDropsBelowTenGrams() {
        var toast = FoodItem(
            name: "Toast", grams: 20,
            base: Macros(kcal: 50, protein: 2, carbs: 9, fat: 1), confidence: .high
        )
        toast.step(-1)
        toast.step(-1)
        XCTAssertEqual(toast.grams, 10)
    }

    // MARK: Typed amounts and servings

    private func eggs() -> FoodItem {
        FoodItem(
            name: "Scrambled eggs", grams: 100,
            base: Macros(kcal: 148, protein: 12, carbs: 1, fat: 10), confidence: .high,
            serving: Serving(name: "egg", grams: 50)
        )
    }

    func testTypedGramsReplaceTheEstimate() {
        var chicken = FoodItem(name: "Chicken", grams: 150, base: Macros(kcal: 248, protein: 46, carbs: 0, fat: 5), confidence: .medium)
        chicken.setAmount(300)
        XCTAssertEqual(chicken.grams, 300)
        XCTAssertEqual(chicken.amountText, "300")
        XCTAssertEqual(chicken.macros, Macros(kcal: 496, protein: 92, carbs: 0, fat: 10))
    }

    func testNonsenseAmountsAreIgnoredAndHugeOnesCapped() {
        var chicken = FoodItem(name: "Chicken", grams: 150, base: Macros(kcal: 248, protein: 46, carbs: 0, fat: 5), confidence: .medium)
        chicken.setAmount(0)
        chicken.setAmount(-20)
        chicken.setAmount(.nan)
        XCTAssertEqual(chicken.grams, 150)
        chicken.setAmount(999_999)
        XCTAssertEqual(chicken.grams, FoodItem.maxGrams)
    }

    func testServingsAndGramsDescribeTheSamePortion() {
        var item = eggs()
        XCTAssertEqual(item.unit, .grams)
        XCTAssertEqual(item.amountText, "100")

        item.setUnit(.servings)
        XCTAssertEqual(item.unit, .servings)
        XCTAssertEqual(item.amountText, "2")
        XCTAssertEqual(item.grams, 100, "switching units must not change the portion")

        item.setAmount(3)
        XCTAssertEqual(item.grams, 150)
        XCTAssertEqual(item.macros, Macros(kcal: 222, protein: 18, carbs: 2, fat: 15))

        item.setUnit(.grams)
        XCTAssertEqual(item.amountText, "150")
    }

    func testFractionalServingsSurviveARoundTrip() {
        var item = FoodItem(name: "Peanut butter", grams: 32, base: Macros(kcal: 190, protein: 7, carbs: 7, fat: 16), confidence: .medium, serving: Serving(name: "tbsp", grams: 16))
        item.setUnit(.servings)
        item.setAmount(1.5)
        XCTAssertEqual(item.grams, 24)
        XCTAssertEqual(item.amountText, "1.5")
        item.setAmount(0.25)
        XCTAssertEqual(item.grams, 4)
        XCTAssertEqual(item.amountText, "0.25")
    }

    func testStepSizeFollowsTheUnit() {
        var item = eggs()
        item.step(1)
        XCTAssertEqual(item.grams, 110)
        item.setUnit(.servings)
        item.setAmount(2)
        item.step(1)
        XCTAssertEqual(item.amountText, "2.5")
        item.step(-1)
        item.step(-1)
        item.step(-1)
        item.step(-1)
        item.step(-1)
        XCTAssertEqual(item.amountText, "0.5", "a step that would empty the portion is ignored")
    }

    func testFoodsWithoutAServingStayInGrams() {
        var chicken = FoodItem(name: "Chicken", grams: 150, base: Macros(kcal: 248, protein: 46, carbs: 0, fat: 5), confidence: .medium)
        XCTAssertNil(chicken.serving)
        chicken.setUnit(.servings)
        XCTAssertEqual(chicken.unit, .grams)
        XCTAssertEqual(chicken.amountText, "150")
    }

    func testParsingTypedAmounts() {
        XCTAssertEqual(FoodItem.parseAmount("150"), 150)
        XCTAssertEqual(FoodItem.parseAmount(" 1.5 "), 1.5)
        XCTAssertEqual(FoodItem.parseAmount("1,5"), 1.5, "decimal comma keyboards")
        XCTAssertEqual(FoodItem.parseAmount("2."), 2, "mid-typing")
        XCTAssertNil(FoodItem.parseAmount(""))
        XCTAssertNil(FoodItem.parseAmount("abc"))
        XCTAssertNil(FoodItem.parseAmount("1.2.3"))
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
