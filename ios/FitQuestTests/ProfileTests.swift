import XCTest
@testable import FitQuest

final class ProfileTests: XCTestCase {
    private func completeDraft() -> ProfileDraft {
        var draft = ProfileDraft()
        draft.sex = .male
        draft.age = "24"
        draft.weight = "165"
        draft.heightFeet = "5"
        draft.heightInches = "10"
        draft.goal = .leanBulk
        draft.experience = .intermediate
        draft.daysPerWeek = 4
        draft.injuries = [.knee]
        draft.equipment = [.barbell, .dumbbells, .pullupBar]
        draft.diet = [.glutenFree, .vegetarian]
        return draft
    }

    // MARK: Draft

    func testEmptyDraftIsNotAProfile() {
        let draft = ProfileDraft()
        XCTAssertNil(draft.profile)
        XCTAssertEqual(draft.bodyProblem, "Choose your sex.")
        XCTAssertEqual(draft.goalProblem, "Choose a goal.")
    }

    func testCompleteDraftBecomesAProfile() throws {
        let draft = completeDraft()
        XCTAssertNil(draft.bodyProblem)
        XCTAssertNil(draft.goalProblem)
        let profile = try XCTUnwrap(draft.profile)
        // Typed in feet, inches and pounds; stored in the metric units the formulas use.
        XCTAssertEqual(profile.heightCm, 177.8, accuracy: 0.001)
        XCTAssertEqual(profile.weightKg, 74.843, accuracy: 0.001)
        XCTAssertEqual(profile.sex, .male)
        XCTAssertEqual(profile.age, 24)
        XCTAssertEqual(profile.goal, .leanBulk)
        XCTAssertEqual(profile.experience, .intermediate)
        XCTAssertEqual(profile.daysPerWeek, 4)
        XCTAssertEqual(profile.injuries, [.knee])
        XCTAssertEqual(profile.equipment, [.barbell, .dumbbells, .pullupBar])
        XCTAssertEqual(profile.diet, [.vegetarian, .glutenFree])
    }

    func testBodyProblemsAreReportedInFormOrder() {
        var draft = completeDraft()
        draft.heightFeet = ""
        XCTAssertEqual(draft.bodyProblem, "Enter your height, from 3 ft 4 in to 8 ft 2 in.")
        draft.weight = ""
        XCTAssertEqual(draft.bodyProblem, "Enter your weight in pounds (66 to 660).")
        draft.age = "abc"
        XCTAssertEqual(draft.bodyProblem, "Enter your age (13 to 100).")
        XCTAssertNil(draft.profile)
    }

    func testHeightIsFeetPlusInches() throws {
        var draft = completeDraft()
        draft.heightInches = ""
        XCTAssertEqual(try XCTUnwrap(draft.profile).heightCm, 152.4, accuracy: 0.001, "Blank inches means none")
        draft.heightInches = "10.5"
        XCTAssertEqual(try XCTUnwrap(draft.profile).heightCm, 179.07, accuracy: 0.001)
        for inches in ["12", "-1", "x"] {
            draft.heightInches = inches
            XCTAssertNotNil(draft.bodyProblem, inches)
        }
        draft.heightInches = "0"
        for feet in ["2", "9", "5.5", "178"] {
            draft.heightFeet = feet
            XCTAssertNotNil(draft.bodyProblem, feet)
        }
        draft.heightFeet = "3"
        draft.heightInches = "3"
        XCTAssertNotNil(draft.bodyProblem, "Below 3 ft 4 in")
        draft.heightInches = "4"
        XCTAssertNil(draft.bodyProblem)
    }

    func testOutOfRangeNumbersAreRejected() {
        var draft = completeDraft()
        draft.age = "12"
        XCTAssertNotNil(draft.bodyProblem)
        draft.age = "101"
        XCTAssertNotNil(draft.bodyProblem)
        draft.age = "13"
        XCTAssertNil(draft.bodyProblem)
        draft.weight = "661"
        XCTAssertNotNil(draft.bodyProblem)
        draft.weight = "65"
        XCTAssertNotNil(draft.bodyProblem)
        draft.weight = "0"
        XCTAssertNotNil(draft.bodyProblem)
        draft.weight = "nan"
        XCTAssertNotNil(draft.bodyProblem)
    }

    func testDecimalCommaAndStraySpacesAreAccepted() throws {
        var draft = completeDraft()
        draft.weight = " 165,5 "
        draft.age = " 24 "
        draft.heightFeet = " 5 "
        XCTAssertEqual(try XCTUnwrap(draft.profile).weightKg, 165.5 * 0.45359237, accuracy: 0.001)
    }

    func testGoalStepNeedsGoalAndExperience() {
        var draft = completeDraft()
        draft.experience = nil
        XCTAssertEqual(draft.goalProblem, "Choose your experience level.")
        draft.goal = nil
        XCTAssertEqual(draft.goalProblem, "Choose a goal.")
        XCTAssertNil(draft.profile)
    }

    func testDraftCanBeRebuiltFromAProfile() throws {
        let profile = try XCTUnwrap(completeDraft().profile)
        let rebuilt = ProfileDraft(profile)
        XCTAssertEqual(rebuilt.heightFeet, "5")
        XCTAssertEqual(rebuilt.heightInches, "10")
        XCTAssertEqual(rebuilt.weight, "165")
        XCTAssertEqual(rebuilt.profile, profile, "Editing and saving without changes must not drift the numbers")
    }

    func testImperialReadouts() throws {
        var profile = try XCTUnwrap(completeDraft().profile)
        XCTAssertEqual(profile.heightText, "5′10″")
        XCTAssertEqual(profile.weightText, "165")
        // A hair under 6 ft must read 6′0″, never 5′12″.
        profile.heightCm = 182.8
        XCTAssertEqual(profile.heightText, "6′0″")
        profile.weightKg = 75
        XCTAssertEqual(profile.weightText, "165.3")
    }

    func testSelectAllEquipment() {
        var draft = ProfileDraft()
        XCTAssertFalse(draft.hasAllEquipment)
        draft.equipment = [.barbell]
        draft.toggleAllEquipment()
        XCTAssertEqual(draft.equipment, Set(UserProfile.Equipment.allCases))
        XCTAssertTrue(draft.hasAllEquipment)
        draft.toggleAllEquipment()
        XCTAssertTrue(draft.equipment.isEmpty, "With everything picked, the same button clears the list")
    }

    // MARK: Stored shape

    // These keys and values are what lands in the database, so a rename is a migration.
    func testProfileEncodesWithThePlanFieldNames() throws {
        let profile = try XCTUnwrap(completeDraft().profile)
        let data = try JSONEncoder().encode(profile)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["sex"] as? String, "male")
        XCTAssertEqual(json["age"] as? Int, 24)
        XCTAssertEqual(try XCTUnwrap(json["height_cm"] as? Double), 177.8, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(json["weight_kg"] as? Double), 74.843, accuracy: 0.001)
        XCTAssertEqual(json["goal"] as? String, "lean_bulk")
        XCTAssertEqual(json["experience"] as? String, "intermediate")
        XCTAssertEqual(json["days_per_week"] as? Int, 4)
        XCTAssertEqual(json["injuries"] as? [String], ["knee"])
        XCTAssertEqual(json["equipment"] as? [String], ["barbell", "dumbbells", "pullup_bar"])
        XCTAssertEqual(json["dietary_restrictions"] as? [String], ["vegetarian", "gluten_free"])
        XCTAssertEqual(try JSONDecoder().decode(UserProfile.self, from: data), profile)
    }

    // Profiles saved before the diet question existed must still load.
    func testAProfileSavedWithoutDietStillDecodes() throws {
        let old = #"{"sex":"female","age":30,"height_cm":165,"weight_kg":60,"goal":"cut","experience":"beginner","days_per_week":3,"injuries":[],"equipment":["bands"]}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(old.utf8))
        XCTAssertTrue(profile.diet.isEmpty)
        XCTAssertEqual(profile.equipment, [.bands])
    }

    // MARK: Pet name

    func testPetNameIsTidiedAndFallsBackToBiscuit() throws {
        var draft = completeDraft()
        XCTAssertEqual(try XCTUnwrap(draft.profile).petName, "Biscuit", "Left blank")
        draft.petName = "  Rex  "
        XCTAssertEqual(try XCTUnwrap(draft.profile).petName, "Rex")
        draft.petName = "Sir Barksalot the Magnificent Third"
        XCTAssertEqual(try XCTUnwrap(draft.profile).petName, "Sir Barksalot the Ma", "Cut to fit its card")
        XCTAssertEqual(ProfileDraft(try XCTUnwrap(draft.profile)).petName, "Sir Barksalot the Ma")
    }

    func testPetNameIsStoredWithTheProfile() throws {
        var draft = completeDraft()
        draft.petName = "Rex"
        let profile = try XCTUnwrap(draft.profile)
        let data = try JSONEncoder().encode(profile)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["pet_name"] as? String, "Rex")
        XCTAssertEqual(try JSONDecoder().decode(UserProfile.self, from: data).petName, "Rex")

        let old = #"{"sex":"female","age":30,"height_cm":165,"weight_kg":60,"goal":"cut","experience":"beginner","days_per_week":3,"injuries":[],"equipment":[]}"#
        XCTAssertEqual(try JSONDecoder().decode(UserProfile.self, from: Data(old.utf8)).petName, "Biscuit", "Saved before pets had names")
    }

    // MARK: Summaries

    func testSummariesReadNaturally() throws {
        var profile = try XCTUnwrap(completeDraft().profile)
        XCTAssertEqual(profile.goalSummary, "Build muscle · 4 days a week")
        XCTAssertEqual(profile.injurySummary, "Knee")
        XCTAssertEqual(profile.equipmentSummary, "Barbell, dumbbells, pull-up bar")
        XCTAssertEqual(profile.dietSummary, "Vegetarian, gluten-free")
        profile.diet = []
        XCTAssertEqual(profile.dietSummary, "No restrictions")
        profile.injuries = []
        profile.equipment = []
        profile.daysPerWeek = 1
        XCTAssertEqual(profile.goalSummary, "Build muscle · 1 day a week")
        XCTAssertEqual(profile.injurySummary, "None")
        XCTAssertEqual(profile.equipmentSummary, "Bodyweight only")
    }

    func testAccountInitials() {
        XCTAssertEqual(Account(id: "1", name: "Alex Moreno", email: "a@b.co").initials, "AM")
        XCTAssertEqual(Account(id: "1", name: "  adharsh ", email: "a@b.co").initials, "A")
        XCTAssertEqual(Account(id: "1", name: "Mary Jane van Dyke", email: "a@b.co").initials, "MD")
        XCTAssertEqual(Account(id: "1", name: "", email: "zed@b.co").initials, "Z")
    }
}
