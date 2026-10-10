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
        case member(Member)
        case addFriend
        case song(Song)
        case template(String)
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
    var toast: String?

    /// Open sheets, bottom first. Only the top one is shown; dismissing it reveals the one beneath.
    private(set) var overlays: [Overlay] = []
    var overlay: Overlay? { overlays.last }

    let targets = Targets()
    var logs: [Day: [Meal]]
    var templates = SampleData.templates
    var activeTemplateID = "push"
    var xp = SampleData.startingXP
    var gymID = "ram"
    /// Not persisted yet, like the rest of the state.
    var hidesProfileFromNonFriends = false

    @ObservationIgnored var foodAnalyzer: FoodAnalyzing = GeminiFoodAnalyzer.fromConfig() ?? MockFoodAnalyzer()

    private var progressByExercise: [String: ExerciseProgress] = [:]
    private var rewardedTemplates: Set<String> = []
    private var friendIDs = SampleData.initialFriendIDs
    private var requestedIDs: Set<String> = []
    private var sessions: [WorkoutSession]
    private let calorieHistory: [Day: Bool]
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(today: Day = Day(), page: Page = .dashboard) {
        self.today = today
        self.page = page
        logs = SampleData.logs(today: today)
        sessions = SampleData.sessions(today: today)
        calorieHistory = SampleData.calorieHistory(today: today)
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
        return DayStatus(calories: calorieHistory[day] ?? false, workout: sessions.contains { $0.day == day })
    }

    /// Finished workouts of one template, newest first.
    func sessions(for templateID: String) -> [WorkoutSession] {
        sessions.filter { $0.templateID == templateID }.sorted { $0.day > $1.day }
    }

    // MARK: Gym

    func isFriend(_ member: Member) -> Bool { friendIDs.contains(member.id) }

    /// A private profile is only open to that member's friends.
    func canView(_ member: Member) -> Bool { isFriend(member) || !member.isPrivate }

    func friends(at gymID: String) -> [Member] {
        SampleData.members.filter { $0.gymID == gymID && isFriend($0) }
    }

    func friendsHere(at gymID: String) -> Int {
        friends(at: gymID).filter(\.atGym).count
    }

    /// Members of a gym who are not friends yet, optionally narrowed by a name search.
    func people(at gymID: String, matching query: String = "") -> [Member] {
        SampleData.members.filter { $0.gymID == gymID && !isFriend($0) && $0.matches(query) }
    }

    func hasRequested(_ member: Member) -> Bool { requestedIDs.contains(member.id) }

    /// Public profiles become friends straight away. Private ones only get a request,
    /// because friendship is what unlocks a private profile.
    func addFriend(_ member: Member) {
        guard !isFriend(member) else { return }
        if member.isPrivate {
            guard requestedIDs.insert(member.id).inserted else { return }
            flash("Friend request sent to \(member.firstName)")
        } else {
            friendIDs.insert(member.id)
            flash("\(member.firstName) is now your friend")
        }
    }

    /// A song's listeners with friends first. Private non-friends are counted, not named.
    func audience(of song: Song) -> SongAudience {
        func resolve(_ ids: [String]) -> [Member] {
            let members = ids.compactMap { id in SampleData.members.first { $0.id == id } }
            return members.filter(isFriend) + members.filter { !isFriend($0) }
        }
        let now = resolve(song.listeningNow), earlier = resolve(song.listenedThisWeek)
        return SongAudience(
            now: now.filter(canView),
            earlier: earlier.filter(canView),
            hiddenCount: (now + earlier).filter { !canView($0) }.count
        )
    }

    // MARK: Sheets

    func present(_ overlay: Overlay) {
        overlays.append(overlay)
    }

    func dismiss() {
        if !overlays.isEmpty { overlays.removeLast() }
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
        overlays.removeAll()
        page = .dashboard
        flash("+\(total.kcal) kcal logged · +\(XPEvent.mealLogged.xp) XP")
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

    /// Makes a template today's session and opens it at the given exercise, or the first unfinished one.
    func startWorkout(_ templateID: String, at exerciseID: String? = nil) {
        guard let template = templates.first(where: { $0.id == templateID }) else { return }
        activeTemplateID = templateID
        let target = exerciseID ?? (template.exercises.first { !isDone($0) } ?? template.exercises.first)?.id
        if let target { present(.exercise(target)) }
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

    /// Awards workout XP and records the session, once per template however many times the last box is re-ticked.
    func completeWorkout() {
        guard let template = activeTemplate, rewardedTemplates.insert(template.id).inserted else { return }
        xp += XPEvent.workoutCompleted.xp
        sessions.append(session(for: template))
        flash("Workout complete · +\(XPEvent.workoutCompleted.xp) XP")
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

    private func session(for template: WorkoutTemplate) -> WorkoutSession {
        let logged = template.exercises.map { (exercise: $0, sets: progress(for: $0).sets.filter(\.done)) }
        // Headline lift: the heaviest completed set of the first exercise that has one.
        let top = logged.first { !$0.sets.isEmpty }.flatMap { entry in
            entry.sets.max { (Double($0.lbs) ?? 0) < (Double($1.lbs) ?? 0) }.map { "\(entry.exercise.name) \($0.lbs) × \($0.reps)" }
        }
        return WorkoutSession(
            id: UUID().uuidString, templateID: template.id, day: today, minutes: nil,
            volume: template.exercises.reduce(0) { $0 + progress(for: $1).volume },
            sets: logged.reduce(0) { $0 + $1.sets.count },
            highlight: top ?? ""
        )
    }

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
