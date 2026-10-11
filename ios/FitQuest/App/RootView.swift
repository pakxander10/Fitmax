import SwiftUI

/// Login, then onboarding, then the app itself: four swipeable pages under a dot nav, with
/// sheets, scrims and the toast layered above.
struct RootView: View {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    private static let pageKey = "fq-page"

    /// `foodAnalyzer` and `mealStore` replace the model's defaults when the app has better ones (Firebase).
    /// `bodyScanner` is nil when this build has no scan server set up.
    init(foodAnalyzer: FoodAnalyzing? = nil, mealStore: MealStoring? = nil, bodyScanner: BodyScanning? = nil) {
        let stored = UserDefaults.standard.object(forKey: Self.pageKey) as? Int
        let model = AppModel(page: stored.flatMap(AppModel.Page.init) ?? .dashboard, mealStore: mealStore ?? LocalMealStore())
        if let foodAnalyzer { model.foodAnalyzer = foodAnalyzer }
        model.bodyScanner = bodyScanner
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            AeroBackground()
            switch model.stage {
            case .launching: LaunchScreen().transition(.opacity)
            case .signedOut: AuthScreen().transition(.opacity)
            case .onboarding: OnboardingFlow().transition(.opacity)
            case .ready: app.transition(.opacity)
            }
        }
        .overlay(alignment: .top) { toast }
        .animation(.easeOut(duration: 0.25), value: model.stage)
        .animation(.easeOut(duration: 0.2), value: model.overlays)
        .animation(.easeOut(duration: 0.2), value: model.toast)
        .environment(model)
        .preferredColorScheme(.light)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .onChange(of: model.page) { UserDefaults.standard.set(model.page.rawValue, forKey: Self.pageKey) }
        .onChange(of: scenePhase) {
            // Roll "today" over if the app sat in the background past midnight.
            if scenePhase == .active { model.today = Day() }
        }
        .task { await model.restoreSession() }
    }

    private var app: some View {
        ZStack {
            Group {
                pager
                NavBar()
            }
            .accessibilityHidden(model.overlay != nil)
            // Every open sheet stays mounted, so going back restores its search text and scroll position.
            ForEach(Array(model.overlays.enumerated()), id: \.offset) { index, overlay in
                sheet(for: overlay)
                    .accessibilityHidden(index != model.overlays.count - 1)
                    .transition(.opacity)
            }
        }
    }

    private var pager: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(AppModel.Page.allCases) { page in
                        PageScroll { content(for: page) }
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding(get: { model.page }, set: { if let page = $0 { model.page = page } }))
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .bottom)
            .onAppear { proxy.scrollTo(model.page, anchor: .leading) }
        }
    }

    @ViewBuilder
    private func content(for page: AppModel.Page) -> some View {
        switch page {
        case .calorie: CaloriePage()
        case .dashboard: DashboardPage()
        case .workout: WorkoutPage()
        case .gym: GymPage()
        }
    }

    @ViewBuilder
    private func sheet(for overlay: AppModel.Overlay) -> some View {
        switch overlay {
        case .meal(let meal, let day): MealDetail(meal: meal, day: day)
        case .logMeal: LogMealFlow()
        case .profile: ProfileSheet()
        case .editProfile: OnboardingFlow(editing: true, draft: model.profile.map(ProfileDraft.init) ?? ProfileDraft())
        case .bodyScan: BodyScanFlow()
        case .pet: PetSheet()
        case .member(let member): MemberProfile(member: member)
        case .addFriend: AddFriendSheet()
        case .song(let song): SongListenersSheet(song: song)
        case .template(let id): TemplateDetail(templateID: id)
        case .exercise(let id): ExerciseDetail(initialID: id)
        case .aboutExercise(let exercise): AboutExerciseCard(exercise: exercise)
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = model.toast {
            Text(message)
                .heading(14)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background {
                    Capsule().fill(.white)
                        .overlay(Capsule().strokeBorder(Theme.aqua.opacity(0.6), lineWidth: 1))
                        .shadow(color: Theme.azure.opacity(0.35), radius: 10, y: 5)
                }
                .padding(.top, 8)
                .padding(.horizontal, 20)
                .transition(.opacity)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

/// Dot pager pinned over the bottom of every page, plus the camera button on the Calorie page.
struct NavBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(AppModel.Page.allCases) { page in
                    let selected = page == model.page
                    Button {
                        withAnimation(.easeOut(duration: 0.32)) { model.page = page }
                    } label: {
                        Group {
                            if selected {
                                Glossy(shape: Circle(), fill: Theme.greenGloss)
                            } else {
                                Circle().fill(Theme.azure.opacity(0.3))
                            }
                        }
                        .frame(width: selected ? 20 : 9, height: selected ? 20 : 9)
                        .frame(width: (selected ? 20 : 9) + 14, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(page.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 13)
            .background {
                Capsule().fill(Theme.glass)
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
                    .shadow(color: Theme.azure.opacity(0.3), radius: 10, y: 5)
            }
            .animation(.easeOut(duration: 0.2), value: model.page)

            if model.page == .calorie {
                Button { model.present(.logMeal) } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background {
                            Glossy(shape: Circle(), fill: Theme.greenGloss)
                                .shadow(color: Theme.green.opacity(0.45), radius: 8, y: 4)
                        }
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Open camera to log a meal")
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 20)
                .transition(.opacity)
            }
        }
        .frame(height: 60)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background {
            // The flexible container is what reaches under the home indicator; a fixed-height
            // gradient on its own stops at the safe area and lets page content show beneath it.
            ZStack(alignment: .bottom) {
                Color.clear
                LinearGradient(
                    stops: [
                        .init(color: Theme.horizon, location: 0),
                        .init(color: Theme.horizon.opacity(0.9), location: 0.45),
                        .init(color: Theme.horizon.opacity(0), location: 1),
                    ],
                    startPoint: .bottom, endPoint: .top
                )
                .frame(height: 160)
            }
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.2), value: model.page == .calorie)
    }
}
