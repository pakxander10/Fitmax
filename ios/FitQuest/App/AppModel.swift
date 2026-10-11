import Foundation
import Observation

/// App state for the whole UI. The account, profile and logged meals come from `auth`, `profiles`
/// and `mealStore`; everything else is still seeded from `SampleData` and kept in memory.
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
        case editProfile
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

    /// Which top-level screen to show.
    enum Stage: Equatable {
        /// Signed in, profile still loading.
        case launching
        case signedOut
        /// Signed in, no profile yet.
        case onboarding
        case ready
    }

    struct NotSignedIn: Error {}

    /// Where meal ideas come from, which decides how the Calorie page describes them.
    enum RecommendationSource: Equatable {
        case sample, ai, recipeDatabase
    }

    /// Where the Calorie page's meal ideas stand.
    enum Recommendations: Equatable {
        case idle, loading
        case loaded([MealRecommendation])
        /// Too few calories left today for another meal.
        case budgetUsed
        /// The service behind the ideas has used up its free requests.
        case limitReached
        case failed
    }

    var today: Day
    var page: Page
    var toast: String?

    /// Open sheets, bottom first. Only the top one is shown; dismissing it reveals the one beneath.
    private(set) var overlays: [Overlay] = []
    var overlay: Overlay? { overlays.last }

    private(set) var account: Account?
    private(set) var profile: UserProfile?
    /// The last attempt to load the profile failed; the launch screen offers a retry.
    private(set) var restoreFailed = false
    private var profileLoaded = false

    var logs: [Day: [Meal]]
    var templates = SampleData.templates
    var activeTemplateID = "push"
    var xp = SampleData.startingXP
    var gymID = "ram"
    /// Not persisted yet, like the rest of the state.
    var hidesProfileFromNonFriends = false

    private(set) var recommendations = Recommendations.idle
    /// The request the current ideas answer, so the same one is never sent twice.
    private var answeredRequest: MealRequest?

    @ObservationIgnored var foodAnalyzer: FoodAnalyzing = GeminiFoodAnalyzer.fromConfig() ?? MockFoodAnalyzer()
    @ObservationIgnored var mealRecommender: MealRecommending = AppModel.configuredRecommender()
    /// The clock, replaceable in tests.
    @ObservationIgnored var now: () -> Date = { Date() }
    @ObservationIgnored private let auth: AuthProviding
    @ObservationIgnored private let profiles: ProfileStoring
    @ObservationIgnored private let mealStore: MealStoring
    /// The save of the most recently logged meal, so tests can wait for it.
    @ObservationIgnored private(set) var pendingSave: Task<Void, Never>?

    private var progressByExercise: [String: ExerciseProgress] = [:]
    private var rewardedTemplates: Set<String> = []
    private var friendIDs = SampleData.initialFriendIDs
    private var requestedIDs: Set<String> = []
    private var sessions: [WorkoutSession]
    private var calorieHistory: [Day: Bool]
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(
        today: Day = Day(), page: Page = .dashboard,
        auth: AuthProviding = LocalAuthService(), profiles: ProfileStoring = LocalProfileStore(),
        mealStore: MealStoring = LocalMealStore(), sampleMeals: Bool = false
    ) {
        self.today = today
        self.page = page
        self.auth = auth
        self.profiles = profiles
        self.mealStore = mealStore
        account = auth.currentAccount
        // A real account starts with an empty food log. The sample one is for previews and tests.
        logs = sampleMeals ? SampleData.logs(today: today) : [:]
        sessions = SampleData.sessions(today: today)
        calorieHistory = sampleMeals ? SampleData.calorieHistory(today: today) : [:]
    }

    /// True while no Gemini key is configured and meal estimates are the canned sample foods.
    var usesSampleFoodEstimates: Bool { foodAnalyzer is MockFoodAnalyzer }

    /// True while accounts live only on this phone, before a real auth backend is configured.
    var usesLocalAccounts: Bool { auth is LocalAuthService }

    // MARK: Session

    var stage: Stage {
        guard account != nil else { return .signedOut }
        guard profileLoaded else { return .launching }
        return profile == nil ? .onboarding : .ready
    }

    /// Daily targets worked out from the profile. The defaults only show before onboarding.
    var targets: Targets { profile.map(TargetCalculator.targets) ?? Targets() }

    /// Loads the profile of whoever was signed in last time. Call once at launch, and again to retry.
    @MainActor
    func restoreSession() async {
        guard let account, !profileLoaded else { return }
        do {
            profile = try await profiles.profile(for: account.id)
            logs = await savedMeals(for: account)
            profileLoaded = true
            restoreFailed = false
        } catch {
            restoreFailed = true
        }
    }

    @MainActor
    func signUp(name: String, email: String, password: String) async throws {
        let account = try await auth.signUp(name: name, email: email, password: password)
        logs = await savedMeals(for: account)
        start(account, profile: nil)
    }

    @MainActor
    func signIn(email: String, password: String) async throws {
        let account = try await auth.signIn(email: email, password: password)
        let profile = try await profiles.profile(for: account.id)
        logs = await savedMeals(for: account)
        start(account, profile: profile)
    }

    /// Saves the onboarding answers and opens the app.
    @MainActor
    func completeOnboarding(_ profile: UserProfile) async throws {
        guard let account else { throw NotSignedIn() }
        try await profiles.save(profile, for: account.id)
        self.profile = profile
    }

    func signOut() {
        try? auth.signOut()
        account = nil
        profile = nil
        profileLoaded = false
        restoreFailed = false
        // The next person to sign in gets their own saved meals, not these.
        logs = [:]
        calorieHistory = [:]
        recommendations = .idle
        answeredRequest = nil
        overlays.removeAll()
        page = .dashboard
    }

    /// The account's saved meals. A store that cannot be read gives an empty log, not a failed sign-in.
    private func savedMeals(for account: Account) async -> [Day: [Meal]] {
        (try? await mealStore.meals(for: account.id)) ?? [:]
    }

    private func start(_ account: Account, profile: UserProfile?) {
        self.account = account
        self.profile = profile
        profileLoaded = true
        restoreFailed = false
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
        // A past day is judged on the meals logged for it, unless the sample history has its own answer.
        let ate = (logs[day] ?? []).map(\.macros).total.kcal
        let onTarget = calorieHistory[day] ?? (ate > 0 && Nutrition.calorieGoalMet(consumed: ate, target: targets.kcal))
        return DayStatus(calories: onTarget, workout: sessions.contains { $0.day == day })
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

    // MARK: Meal ideas

    /// True while no key is configured and meal ideas are canned, not matched to the person.
    var usesSampleRecommendations: Bool { recommendationSource == .sample }

    var recommendationSource: RecommendationSource {
        if mealRecommender is SampleMealRecommender { return .sample }
        return mealRecommender is GeminiMealRecommender ? .ai : .recipeDatabase
    }

    /// The recipe database when it has a key, then Gemini, then canned samples.
    private static func configuredRecommender() -> MealRecommending {
        if let database = SpoonacularMealRecommender.fromConfig() { return database }
        if let gemini = GeminiMealRecommender.fromConfig() { return gemini }
        return SampleMealRecommender()
    }

    /// What a meal idea must fit right now. Nil once today's calories are all but used.
    var mealRequest: MealRequest? {
        guard let budget = Nutrition.mealBudget(remainingKcal: remainingKcal, targetKcal: targets.kcal) else { return nil }
        return MealRequest(
            budget: budget,
            remainingProtein: max(0, targets.protein - consumed.protein),
            slot: .suggested(atHour: Calendar.current.component(.hour, from: now())),
            goal: profile?.goal,
            diet: profile?.dietList ?? []
        )
    }

    /// Fetches meal ideas for the current request. Does nothing if the ideas on show already answer it,
    /// unless `force` asks for different ones.
    @MainActor
    func refreshRecommendations(force: Bool = false) async {
        guard let request = mealRequest else {
            recommendations = .budgetUsed
            answeredRequest = nil
            return
        }
        guard force || request != answeredRequest else { return }
        var shown: [String] = []
        if force, case .loaded(let meals) = recommendations { shown = meals.map(\.name) }
        recommendations = .loading
        answeredRequest = request
        do {
            let meals = try await mealRecommender.recommend(request, avoiding: shown)
            // A newer request took over while this one was in flight.
            guard answeredRequest == request else { return }
            recommendations = .loaded(Self.fitting(meals, request: request))
        } catch {
            guard answeredRequest == request else { return }
            answeredRequest = nil
            if case GeminiClient.ClientError.badResponse(GeminiClient.quotaStatus) = error {
                recommendations = .limitReached
            } else if error as? MealRecommendationError == .limitReached {
                recommendations = .limitReached
            } else {
                recommendations = .failed
            }
        }
    }

    /// The request is enforced here, whatever the recommender returned: nothing over budget, nothing whose
    /// name breaks the diet, no repeats, four at most.
    private static func fitting(_ meals: [MealRecommendation], request: MealRequest) -> [MealRecommendation] {
        var seen: Set<String> = []
        return Array(meals.filter {
            $0.kcal > 0 && $0.kcal <= request.budget && DietScreen.passes(request.diet, texts: [$0.name])
                && seen.insert($0.name.lowercased()).inserted
        }
        .prefix(GeminiMealRecommender.count))
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
        if let account {
            // Saved in the background, one after another so they land in the order they were logged.
            pendingSave = Task { [mealStore, today, previous = pendingSave] in
                await previous?.value
                try? await mealStore.save(meal, on: today, for: account.id)
            }
        }
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
