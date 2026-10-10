import SwiftUI

/// Four swipeable pages under a dot nav, with sheets, scrims and the toast layered above.
struct RootView: View {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    private static let pageKey = "fq-page"

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.pageKey) as? Int
        _model = State(initialValue: AppModel(page: stored.flatMap(AppModel.Page.init) ?? .dashboard))
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            pager
            NavBar()
            overlay
        }
        .overlay(alignment: .top) { toast }
        .animation(.easeOut(duration: 0.2), value: model.overlay)
        .animation(.easeOut(duration: 0.2), value: model.toast)
        .environment(model)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .onChange(of: model.page) { UserDefaults.standard.set(model.page.rawValue, forKey: Self.pageKey) }
        .onChange(of: scenePhase) {
            // Roll "today" over if the app sat in the background past midnight.
            if scenePhase == .active { model.today = Day() }
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
    private var overlay: some View {
        switch model.overlay {
        case .meal(let meal, let day): MealDetail(meal: meal, day: day).transition(.opacity)
        case .logMeal: LogMealFlow().transition(.opacity)
        case .profile: ProfileSheet().transition(.opacity)
        case .pet: PetSheet().transition(.opacity)
        case .friend(let friend): FriendProfile(friend: friend).transition(.opacity)
        case .exercise(let id): ExerciseDetail(initialID: id).transition(.opacity)
        case .aboutExercise(let exercise): AboutExerciseCard(exercise: exercise).transition(.opacity)
        case nil: EmptyView()
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = model.toast {
            Text(message)
                .mono(color: Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Theme.surfaceElevated)
                .overlay(Rectangle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
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
                        Circle()
                            .strokeBorder(selected ? Theme.white : Theme.muted, lineWidth: 1)
                            .frame(width: selected ? 20 : 8, height: selected ? 20 : 8)
                            .frame(width: (selected ? 20 : 8) + 14, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(page.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 13)
            .background(Capsule().fill(Theme.canvas))
            .overlay(Capsule().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
            .animation(.easeOut(duration: 0.2), value: model.page)

            if model.page == .calorie {
                Button { model.overlay = .logMeal } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Theme.canvas))
                        .overlay(Circle().strokeBorder(Theme.white, lineWidth: 1))
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
        .background(alignment: .bottom) {
            LinearGradient(
                stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.6), .init(color: .black.opacity(0), location: 1)],
                startPoint: .bottom, endPoint: .top
            )
            .frame(height: 130)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.2), value: model.page == .calorie)
    }
}
