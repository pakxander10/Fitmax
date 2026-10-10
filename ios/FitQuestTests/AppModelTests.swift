import XCTest
@testable import FitQuest

final class AppModelTests: XCTestCase {
    private let today = Day(key: "2026-10-10")
    private func makeModel() -> AppModel { AppModel(today: today) }

    // MARK: Calories

    func testSeededDayTotals() {
        let model = makeModel()
        XCTAssertEqual(model.consumed.kcal, 1_200)
        XCTAssertEqual(model.remainingKcal, 800)
        XCTAssertEqual(model.mood, .happy)
    }

    func testSavingAMealUpdatesTodayAwardsXPAndReturnsToDashboard() {
        let model = makeModel()
        model.page = .calorie
        model.overlay = .logMeal
        let items = SampleData.photoEstimate

        model.saveMeal(slot: .dinner, items: items, source: .photo)

        XCTAssertEqual(model.logs[today]?.count, 4)
        XCTAssertEqual(model.logs[today]?.last?.name, "Grilled chicken breast, Brown rice, Roasted broccoli")
        XCTAssertEqual(model.consumed.kcal, 1_700)
        XCTAssertEqual(model.xp, 1_350)
        XCTAssertEqual(model.page, .dashboard)
        XCTAssertNil(model.overlay)
        XCTAssertEqual(model.toast, "+500 KCAL LOGGED · +10 XP")
    }

    func testRemainingGoesNegativeWhenOverBudget() {
        let model = makeModel()
        let feast = FoodItem(name: "Feast", grams: 100, base: Macros(kcal: 1_100, protein: 0, carbs: 0, fat: 0), confidence: .low)
        model.saveMeal(slot: .dinner, items: [feast], source: .text)
        XCTAssertEqual(model.remainingKcal, -300)
    }

    // MARK: Week strip

    func testDayStatus() {
        let model = makeModel()
        XCTAssertEqual(model.status(for: today), DayStatus(calories: false, workout: false))
        XCTAssertEqual(model.status(for: today.adding(1)), DayStatus())
        XCTAssertEqual(model.status(for: today.adding(-1)), DayStatus(calories: true, workout: true))
        XCTAssertEqual(model.status(for: today.adding(-2)), DayStatus(calories: true, workout: false))
        XCTAssertEqual(model.status(for: today.adding(-30)), DayStatus())
    }

    // MARK: Workout

    func testCompletingASetFillsBlankRepsAndRIR() throws {
        let model = makeModel()
        let bench = try XCTUnwrap(model.activeTemplate?.exercises.first)

        model.toggleSet(0, of: bench)
        XCTAssertEqual(model.progress(for: bench).sets[0], SetEntry(lbs: "155", reps: "8", rir: "2", done: true))

        model.setEntry(1, of: bench) { $0.reps = "6"; $0.rir = "1" }
        model.toggleSet(1, of: bench)
        XCTAssertEqual(model.progress(for: bench).sets[1], SetEntry(lbs: "155", reps: "6", rir: "1", done: true))
        XCTAssertEqual(model.progress(for: bench).volume, 155 * 8 + 155 * 6)
    }

    func testAddAndRemoveSets() throws {
        let model = makeModel()
        let bench = try XCTUnwrap(model.activeTemplate?.exercises.first)
        model.addSet(to: bench)
        XCTAssertEqual(model.progress(for: bench).sets.count, 5)
        for _ in 0..<10 { model.removeSet(from: bench) }
        XCTAssertEqual(model.progress(for: bench).sets.count, 1)
    }

    func testFinishingExercisesAdvancesThenCompletesTheWorkoutOnce() throws {
        let model = makeModel()
        let ids = try XCTUnwrap(model.activeTemplate?.exercises.map(\.id))
        XCTAssertEqual(ids.count, 5)

        // Finishing the last one first wraps round to the first pending exercise.
        XCTAssertEqual(model.toggleExerciseDone(ids[4]), .next(ids[0]))
        XCTAssertEqual(model.toggleExerciseDone(ids[0]), .next(ids[1]))
        XCTAssertEqual(model.toggleExerciseDone(ids[1]), .next(ids[2]))
        XCTAssertEqual(model.toggleExerciseDone(ids[2]), .next(ids[3]))
        XCTAssertFalse(model.workoutDone)
        XCTAssertEqual(model.toggleExerciseDone(ids[3]), .workoutComplete)
        XCTAssertTrue(model.workoutDone)

        model.completeWorkout()
        XCTAssertEqual(model.xp, 1_440)
        XCTAssertEqual(model.toast, "WORKOUT COMPLETE · +100 XP")

        // Un-ticking and re-ticking must not pay out twice.
        XCTAssertEqual(model.toggleExerciseDone(ids[3]), .undone)
        XCTAssertEqual(model.toggleExerciseDone(ids[3]), .workoutComplete)
        model.completeWorkout()
        XCTAssertEqual(model.xp, 1_440)
    }

    func testReplaceSwapsInTheSubstitute() throws {
        let model = makeModel()
        let landmine = try XCTUnwrap(model.activeTemplate?.exercises[1])
        model.replaceExercise(landmine)
        let swapped = try XCTUnwrap(model.activeTemplate?.exercises[1])
        XCTAssertEqual(swapped.name, "Half-kneeling dumbbell press")
        XCTAssertEqual(swapped.alternative, "Landmine press")
    }

    func testRemovingTheActiveTemplateFallsBackToTheFirst() {
        let model = makeModel()
        XCTAssertEqual(model.activeTemplate?.id, "push")
        model.removeTemplate("push")
        XCTAssertEqual(model.activeTemplate?.id, "pull")
        model.removeTemplate("pull")
        model.removeTemplate("legs")
        XCTAssertNil(model.activeTemplate)
        XCTAssertFalse(model.workoutDone)
    }

    func testRenameIgnoresBlankNames() {
        let model = makeModel()
        model.renameTemplate("push", to: "  Chest day ")
        XCTAssertEqual(model.templates[0].name, "Chest day")
        model.renameTemplate("push", to: "   ")
        XCTAssertEqual(model.templates[0].name, "Chest day")
    }
}
