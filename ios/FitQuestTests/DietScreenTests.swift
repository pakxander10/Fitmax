import XCTest
@testable import FitQuest

/// The second look at a recipe's own words, after the database's diet labels.
final class DietScreenTests: XCTestCase {
    private func passes(_ diet: [UserProfile.Diet], _ texts: String...) -> Bool {
        DietScreen.passes(diet, texts: texts)
    }

    func testNutAllergyCatchesNutsByName() {
        XCTAssertFalse(passes([.nutAllergy], "Butternut Squash Tofu Salad With Toasted Hazelnuts"))
        XCTAssertFalse(passes([.nutAllergy], "Noodle salad", "soba noodles", "peanut butter", "lime"))
        XCTAssertFalse(passes([.nutAllergy], "Pesto pasta", "basil", "pine nuts"))
        XCTAssertFalse(passes([.nutAllergy], "Granola", "oats", "Almond milk"))
    }

    func testWordsThatOnlyLookLikeNutsAreFine() {
        XCTAssertTrue(passes([.nutAllergy], "Butternut squash soup", "nutmeg", "coconut milk", "water chestnuts"))
    }

    func testShellfish() {
        XCTAssertFalse(passes([.shellfishAllergy], "Paella", "rice", "prawns"))
        XCTAssertFalse(passes([.kosher], "Shrimp tacos"))
        XCTAssertTrue(passes([.shellfishAllergy], "Fish tacos", "cod", "lime"))
    }

    func testVegetarianVeganAndPescatarian() {
        XCTAssertFalse(passes([.vegetarian], "Bean soup", "beans", "bacon"))
        XCTAssertFalse(passes([.vegetarian], "Caesar salad", "romaine", "anchovies"))
        XCTAssertTrue(passes([.vegetarian], "Cheese omelette", "eggs", "cheddar cheese"))
        XCTAssertFalse(passes([.vegan], "White bean and kale soup", "navy beans", "parmesan rind"))
        XCTAssertFalse(passes([.vegan], "Fried rice", "rice", "egg"))
        XCTAssertTrue(passes([.vegan], "Stuffed eggplant", "eggplant", "coconut milk", "peanut butter"))
        XCTAssertFalse(passes([.pescatarian], "Chicken curry"))
        XCTAssertTrue(passes([.pescatarian], "Salmon and prawn curry"))
    }

    func testHalalAndKosherLeaveOutWhatCanBeSeen() {
        XCTAssertFalse(passes([.halal], "Risotto", "arborio rice", "white wine"))
        XCTAssertFalse(passes([.halal], "Pork dumplings"))
        XCTAssertFalse(passes([.kosher], "Split pea soup", "ham hock"))
        XCTAssertTrue(passes([.halal, .kosher], "Chicken and rice", "chicken thighs", "rice"))
    }

    func testDairyFree() {
        XCTAssertFalse(passes([.dairyFree], "Greek salad", "feta", "olives"))
        XCTAssertTrue(passes([.dairyFree], "Dal", "lentils", "coconut milk"))
    }

    func testEveryRuleApplies() {
        XCTAssertFalse(passes([.vegetarian, .nutAllergy], "Veggie stir-fry", "tofu", "cashews"))
        XCTAssertTrue(passes([], "Bacon cheeseburger with peanut sauce"))
    }
}
