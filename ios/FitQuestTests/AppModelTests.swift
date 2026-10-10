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
        XCTAssertEqual(model.mood, .neutral)
    }

    func testSavingAMealUpdatesTodayAwardsXPAndReturnsToDashboard() {
        let model = makeModel()
        model.page = .calorie
        model.present(.logMeal)
        let items = SampleData.photoEstimate

        model.saveMeal(slot: .dinner, items: items, source: .photo)

        XCTAssertEqual(model.logs[today]?.count, 4)
        XCTAssertEqual(model.logs[today]?.last?.name, "Grilled chicken breast, Brown rice, Roasted broccoli")
        XCTAssertEqual(model.consumed.kcal, 1_700)
        XCTAssertEqual(model.xp, 1_350)
        XCTAssertEqual(model.page, .dashboard)
        XCTAssertNil(model.overlay)
        XCTAssertEqual(model.toast, "+500 kcal logged · +10 XP")
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

        let before = model.sessions(for: "push").count
        model.completeWorkout()
        XCTAssertEqual(model.xp, 1_440)
        XCTAssertEqual(model.toast, "Workout complete · +100 XP")
        XCTAssertEqual(model.mood, .happy)
        XCTAssertEqual(model.sessions(for: "push").count, before + 1)

        // Un-ticking and re-ticking must not pay out twice.
        XCTAssertEqual(model.toggleExerciseDone(ids[3]), .undone)
        XCTAssertEqual(model.toggleExerciseDone(ids[3]), .workoutComplete)
        model.completeWorkout()
        XCTAssertEqual(model.xp, 1_440)
        XCTAssertEqual(model.sessions(for: "push").count, before + 1)
    }

    func testCompletedWorkoutIsRecordedWithWhatWasLifted() throws {
        let model = makeModel()
        let exercises = try XCTUnwrap(model.activeTemplate?.exercises)
        model.toggleSet(0, of: exercises[0])
        model.toggleSet(1, of: exercises[0])
        model.toggleSet(0, of: exercises[1])
        for exercise in exercises { _ = model.toggleExerciseDone(exercise.id) }
        model.completeWorkout()

        let session = try XCTUnwrap(model.sessions(for: "push").first)
        XCTAssertEqual(session.day, today)
        XCTAssertEqual(session.sets, 3)
        XCTAssertEqual(session.volume, 155 * 8 * 2 + 70 * 10)
        XCTAssertEqual(session.highlight, "Barbell bench press 155 × 8")
    }

    func testSessionHistoryIsPerTemplateNewestFirst() {
        let model = makeModel()
        for id in ["push", "pull", "legs"] {
            let sessions = model.sessions(for: id)
            XCTAssertGreaterThanOrEqual(sessions.count, 3, id)
            XCTAssertTrue(sessions.allSatisfy { $0.templateID == id })
            XCTAssertEqual(sessions.map(\.day), sessions.map(\.day).sorted(by: >))
            XCTAssertTrue(sessions.allSatisfy { $0.day < today })
        }
        XCTAssertTrue(model.sessions(for: "nope").isEmpty)
    }

    // The week strip and the session history must tell the same story.
    func testPastWorkoutDaysMatchTheSessionHistory() {
        let model = makeModel()
        let sessionDays = Set(["push", "pull", "legs"].flatMap { model.sessions(for: $0) }.map(\.day))
        for back in 1...9 {
            let day = today.adding(-back)
            XCTAssertEqual(model.status(for: day).workout, sessionDays.contains(day), "\(back) days ago")
        }
    }

    // MARK: Sheets

    func testSheetsStackAndDismissOneAtATime() {
        let model = makeModel()
        model.present(.template("pull"))
        model.startWorkout("pull")
        XCTAssertEqual(model.activeTemplate?.id, "pull")
        XCTAssertEqual(model.overlay, .exercise("row"))

        model.dismiss()
        XCTAssertEqual(model.overlay, .template("pull"))
        model.dismiss()
        XCTAssertNil(model.overlay)
        model.dismiss()
        XCTAssertNil(model.overlay)
    }

    func testStartWorkoutResumesAtTheFirstUnfinishedExercise() {
        let model = makeModel()
        _ = model.toggleExerciseDone("bench")
        model.startWorkout("push")
        XCTAssertEqual(model.overlay, .exercise("landmine"))
        model.dismiss()
        model.startWorkout("push", at: "pushdown")
        XCTAssertEqual(model.overlay, .exercise("pushdown"))
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

    // MARK: Gym

    func testFriendsAndOtherMembersAreSplitByGym() {
        let model = makeModel()
        XCTAssertEqual(model.friends(at: "ram").map(\.id), ["JK", "MP", "SL", "DR", "AN"])
        XCTAssertEqual(model.friends(at: "cs").map(\.id), ["TW", "NB", "CH"])
        XCTAssertEqual(model.friendsHere(at: "ram"), 3)
        XCTAssertEqual(model.friendsHere(at: "cs"), 1)

        let ram = model.people(at: "ram"), cs = model.people(at: "cs")
        XCTAssertGreaterThan(ram.count, 3)
        XCTAssertGreaterThan(cs.count, 3)
        XCTAssertTrue(ram.allSatisfy { $0.gymID == "ram" && !model.isFriend($0) })
        XCTAssertTrue(cs.allSatisfy { $0.gymID == "cs" && !model.isFriend($0) })
    }

    func testPeopleSearchMatchesNamesLooselyWithinTheGym() {
        let model = makeModel()
        XCTAssertEqual(model.people(at: "ram", matching: "pri").map(\.name), ["Priya Shah"])
        XCTAssertEqual(model.people(at: "ram", matching: "  SHAH ").map(\.name), ["Priya Shah"])
        XCTAssertEqual(model.people(at: "ram", matching: " ").count, model.people(at: "ram").count)
        XCTAssertTrue(model.people(at: "ram", matching: "zzz").isEmpty)
        // Existing friends and people from another gym never come back as suggestions.
        XCTAssertTrue(model.people(at: "ram", matching: "Jordan").isEmpty)
        XCTAssertTrue(model.people(at: "ram", matching: "Elena").isEmpty)
        XCTAssertEqual(model.people(at: "cs", matching: "elena").map(\.id), ["EP"])
    }

    func testAddingAFriendMovesThemOutOfSuggestions() throws {
        let model = makeModel()
        let priya = try XCTUnwrap(model.people(at: "ram").first { $0.id == "PS" })

        model.addFriend(priya)
        model.addFriend(priya)

        XCTAssertTrue(model.isFriend(priya))
        XCTAssertEqual(model.friends(at: "ram").filter { $0.id == "PS" }.count, 1)
        XCTAssertFalse(model.people(at: "ram").contains(priya))
        XCTAssertEqual(model.toast, "Priya is now your friend")
    }

    func testSongAudienceListsEveryoneButKeepsPrivateStrangersAnonymous() throws {
        let model = makeModel()
        let tokyoDrift = try XCTUnwrap(SampleData.songs["ram"]?.first)
        XCTAssertEqual(tokyoDrift.title, "Tokyo Drift")

        var audience = model.audience(of: tokyoDrift)
        XCTAssertEqual(audience.now.map(\.id), ["JK", "MP", "SL", "PS"])
        XCTAssertEqual(audience.earlier.map(\.id), ["LM", "HC", "OH"])
        XCTAssertEqual(audience.hiddenCount, 1)
        XCTAssertEqual(audience.total, 8)

        // Friends are listed first within each group.
        let omar = try XCTUnwrap(model.people(at: "ram").first { $0.id == "OH" })
        model.addFriend(omar)
        audience = model.audience(of: tokyoDrift)
        XCTAssertEqual(audience.earlier.map(\.id), ["OH", "LM", "HC"])
        XCTAssertEqual(audience.total, 8)
    }

    // Friends can see private profiles, so adding one must not be instant.
    func testAddingAPrivateProfileOnlySendsARequest() throws {
        let model = makeModel()
        let tokyoDrift = try XCTUnwrap(SampleData.songs["ram"]?.first)
        let zoe = try XCTUnwrap(model.people(at: "ram").first { $0.id == "ZP" })
        XCTAssertTrue(zoe.isPrivate)
        XCTAssertFalse(model.canView(zoe))
        XCTAssertFalse(model.hasRequested(zoe))

        model.addFriend(zoe)

        XCTAssertTrue(model.hasRequested(zoe))
        XCTAssertFalse(model.isFriend(zoe))
        XCTAssertFalse(model.canView(zoe))
        XCTAssertEqual(model.toast, "Friend request sent to Zoe")
        XCTAssertTrue(model.people(at: "ram").contains(zoe))
        XCTAssertEqual(model.audience(of: tokyoDrift).hiddenCount, 1)
    }

    func testProfileIsVisibleToEveryoneUntilHidden() {
        let model = makeModel()
        XCTAssertFalse(model.hidesProfileFromNonFriends)
        model.hidesProfileFromNonFriends = true
        XCTAssertTrue(model.hidesProfileFromNonFriends)
    }

    // MARK: Sample data integrity

    func testMemberIDsAreUnique() {
        let ids = SampleData.members.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(SampleData.initialFriendIDs.isSubset(of: ids))
    }

    func testEverySongListenerIsAMemberOfThatGym() {
        let byID = Dictionary(uniqueKeysWithValues: SampleData.members.map { ($0.id, $0) })
        for (gymID, songs) in SampleData.songs {
            for song in songs {
                XCTAssertTrue(Set(song.listeningNow).isDisjoint(with: song.listenedThisWeek), song.title)
                for id in song.listeningNow + song.listenedThisWeek {
                    XCTAssertEqual(byID[id]?.gymID, gymID, "\(id) on \(song.title)")
                }
                // Whoever is listed as listening now has this as their current song.
                for id in song.listeningNow {
                    XCTAssertEqual(byID[id]?.song, song.title, "\(id) on \(song.title)")
                }
            }
        }
    }
}
