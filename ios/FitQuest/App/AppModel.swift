import Foundation
import Observation

/// In-memory app state for the whole UI. Seeded from `SampleData`; nothing is persisted or
/// fetched yet, so SwiftData and the API client slot in behind these same properties.
@Observable
final class AppModel {
    enum Page: Int, CaseIterable, Identifiable {
        case calorie, dashboard, workout, gym

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .calorie: "Calorie"
            case .dashboard: "Dashboard"
            case .workout: "Workout"
            case .gym: "Your gym"
            }
        }
    }

    enum Overlay: Equatable {
        case meal(Meal, Day)
        case logMeal
        case profile
        case pet
        case friend(Friend)
        case exercise(String)
        case aboutExercise(Exercise)
    }

    enum FinishOutcome: Equatable {
        case undone
        case next(String)
        case workoutComplete
    }

    var today: Day
    var page: Page
    var overlay: Overlay?
    var toast: String?

    let targets = Targets()
    var logs: [Day: [Meal]]
    var templates = SampleData.templates
    var activeTemplateID = "push"
    var xp = SampleData.startingXP
    var gymID = "ram"

    @ObservationIgnored var foodAnalyzer: FoodAnalyzing = MockFoodAnalyzer()

    private var progressByExercise: [String: ExerciseProgress] = [:]
    private var rewardedTemplates: Set<String> = []
    private let history: [Day: DayStatus]
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(today: Day = Day(), page: Page = .dashboard) {
        self.today = today
        self.page = page
        logs = SampleData.logs(today: today)
        history = SampleData.history(today: today)
    }

    // MARK: Derived state

    var consumed: Macros { (logs[today] ?? []).map(\.macros).total }
    var remainingKcal: Int { targets.kcal - consumed.kcal }
    var loggedDays: [Day] { logs.keys.sorted(by: >) }
    var calorieGoalMet: Bool { Nutrition.calorieGoalMet(consumed: consumed.kcal, target: targets.kcal) }
    var mood: Mood { Nutrition.mood(consumedKcal: consumed.kcal, targetKcal: targets.kcal, workoutDone: workoutDone) }
    var game: GameState { GameState(xp: xp, streakDays: SampleData.streakDays) }
    var points: Int { SampleData.startingPoints + max(0, xp - SampleData.startingXP) / 2 }
    var gym: Gym { SampleData.gyms.first { $0.id == gymID } ?? SampleData.gyms[0] }

    var activeTemplate: WorkoutTemplate? {
        templates.first { $0.id == activeTemplateID } ?? templates.first
    }

    var workoutDone: Bool {
        guard let exercises = activeTemplate?.exercises, !exercises.isEmpty else { return false }
        return exercises.allSatisfy(isDone)
    }

    var doneCount: Int { activeTemplate?.exercises.filter(isDone).count ?? 0 }

    func status(for day: Day) -> DayStatus {
        if day == today { return DayStatus(calories: calorieGoalMet, workout: workoutDone) }
        if day > today { return DayStatus() }
        return history[day] ?? DayStatus()
    }

    // MARK: Food

    func saveMeal(slot: MealSlot, items: [FoodItem], source: MealSource, at date: Date = .now) {
        let total = items.map(\.macros).total
        let meal = Meal(
            id: UUID().uuidString, slot: slot, time: Self.clock.string(from: date),
            name: items.map(\.name).joined(separator: ", "), macros: total, source: source
        )
        logs[today, default: []].append(meal)
        xp += XPEvent.mealLogged.xp
        overlay = nil
        page = .dashboard
        flash("+\(total.kcal) KCAL LOGGED · +\(XPEvent.mealLogged.xp) XP")
    }

    // MARK: Templates

    func renameTemplate(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[index].name = trimmed
    }

    func removeTemplate(_ id: String) {
        templates.removeAll { $0.id == id }
    }

    func removeExercise(_ exercise: Exercise) {
        updateActiveExercises { $0.removeAll { $0.id == exercise.id } }
    }

    /// Swaps an exercise for its listed substitute, keeping the original as the new substitute.
    func replaceExercise(_ exercise: Exercise) {
        updateActiveExercises { exercises in
            guard let index = exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
            exercises[index].name = exercise.alternative
            exercises[index].alternative = exercise.name
        }
    }

    // MARK: Set logging

    func progress(for exercise: Exercise) -> ExerciseProgress {
        progressByExercise[exercise.id] ?? ExerciseProgress(for: exercise)
    }

    func isDone(_ exercise: Exercise) -> Bool {
        progressByExercise[exercise.id]?.done == true
    }

    func setEntry(_ index: Int, of exercise: Exercise, _ change: (inout SetEntry) -> Void) {
        updateProgress(of: exercise) { progress in
            guard progress.sets.indices.contains(index) else { return }
            change(&progress.sets[index])
        }
    }

    /// Ticks a set. Blank reps and RIR default to the top of the rep range and RIR 2.
    func toggleSet(_ index: Int, of exercise: Exercise) {
        setEntry(index, of: exercise) { entry in
            entry.done.toggle()
            guard entry.done else { return }
            if entry.reps.isEmpty { entry.reps = String(exercise.reps.upperBound) }
            if entry.rir.isEmpty { entry.rir = "2" }
        }
    }

    func addSet(to exercise: Exercise) {
        updateProgress(of: exercise) { progress in
            progress.sets.append(SetEntry(lbs: progress.sets.last?.lbs ?? String(exercise.lbs)))
        }
    }

    func removeSet(from exercise: Exercise) {
        updateProgress(of: exercise) { progress in
            if progress.sets.count > 1 { progress.sets.removeLast() }
        }
    }

    /// Flips an exercise's done flag and says where the session should go next.
    func toggleExerciseDone(_ id: String) -> FinishOutcome {
        guard let exercises = activeTemplate?.exercises,
              let index = exercises.firstIndex(where: { $0.id == id }) else { return .undone }
        updateProgress(of: exercises[index]) { $0.done.toggle() }
        guard isDone(exercises[index]) else { return .undone }
        let pending = exercises[(index + 1)...].first { !isDone($0) } ?? exercises.first { !isDone($0) }
        if let pending { return .next(pending.id) }
        return .workoutComplete
    }

    /// Awards workout XP once per template, however many times the last box is re-ticked.
    func completeWorkout() {
        guard let template = activeTemplate, rewardedTemplates.insert(template.id).inserted else { return }
        xp += XPEvent.workoutCompleted.xp
        flash("WORKOUT COMPLETE · +\(XPEvent.workoutCompleted.xp) XP")
    }

    // MARK: Toast

    func flash(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(2_200))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    // MARK: Private

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func updateActiveExercises(_ change: (inout [Exercise]) -> Void) {
        guard let id = activeTemplate?.id, let index = templates.firstIndex(where: { $0.id == id }) else { return }
        change(&templates[index].exercises)
    }

    private func updateProgress(of exercise: Exercise, _ change: (inout ExerciseProgress) -> Void) {
        var progress = progress(for: exercise)
        change(&progress)
        progressByExercise[exercise.id] = progress
    }
}
