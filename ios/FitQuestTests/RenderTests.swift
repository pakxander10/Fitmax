#if os(macOS)
import SwiftUI
import XCTest
@testable import FitQuest

/// Renders each screen to a PNG so layouts can be checked without a simulator.
/// Opt-in: `FQ_RENDER_DIR=/some/dir swift test --filter RenderTests`
final class RenderTests: XCTestCase {
    @MainActor
    func testRenderScreens() async throws {
        guard let dir = ProcessInfo.processInfo.environment["FQ_RENDER_DIR"] else {
            throw XCTSkip("Set FQ_RENDER_DIR to render screens")
        }
        let out = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let model = AppModel(today: Day(key: "2026-10-10"), sampleData: true)
        let meal = try XCTUnwrap(model.logs[model.today]?[1])
        let friend = SampleData.members[1]
        let song = try XCTUnwrap(SampleData.songs["ram"]?.first)
        let bench = try XCTUnwrap(model.activeTemplate?.exercises.first)
        model.toggleSet(0, of: bench)
        model.mealRecommender = SampleMealRecommender(delay: .zero)
        await model.refreshRecommendations()
        let draft = ProfileDraft(SampleData.profile)

        let screens: [(String, AnyView)] = [
            ("01-calorie", AnyView(PageScroll { CaloriePage() })),
            ("25-calorie-empty", AnyView(PageScroll { CaloriePage() }.environment(AppModel(today: Day(key: "2026-10-10"))))),
            ("02-dashboard", AnyView(PageScroll { DashboardPage() })),
            ("03-workout", AnyView(PageScroll { WorkoutPage() })),
            ("04-gym", AnyView(PageScroll { GymPage() })),
            ("17-gym-picker", AnyView(PageScroll { GymPage(pickerOpen: true) })),
            ("05-meal-detail", AnyView(MealDetail(meal: meal, day: model.today))),
            ("06-log-meal-capture", AnyView(LogMealFlow())),
            ("07-log-meal-review", AnyView(LogMealFlow(previewItems: SampleData.photoEstimate))),
            ("08-profile", AnyView(ProfileSheet())),
            ("09-pet", AnyView(PetSheet())),
            ("10-friend", AnyView(MemberProfile(member: friend))),
            ("15-add-friend", AnyView(AddFriendSheet())),
            ("16-song-listeners", AnyView(SongListenersSheet(song: song))),
            ("11-exercise", AnyView(ExerciseDetail(initialID: bench.id))),
            ("14-template", AnyView(TemplateDetail(templateID: "push"))),
            ("12-about-exercise", AnyView(AboutExerciseCard(exercise: bench))),
            ("13-nav", AnyView(NavBar().frame(height: 140))),
            ("18-sign-in", AnyView(AuthScreen())),
            ("19-sign-up", AnyView(AuthScreen(mode: .signUp))),
            ("20-onboarding-body", AnyView(OnboardingFlow(draft: draft))),
            ("21-onboarding-goal", AnyView(OnboardingFlow(step: .goal, draft: draft))),
            ("22-onboarding-training", AnyView(OnboardingFlow(step: .training, draft: draft))),
            ("26-onboarding-diet", AnyView(OnboardingFlow(step: .diet, draft: draft))),
            ("27-onboarding-pet", AnyView(OnboardingFlow(step: .pet, draft: draft))),
            ("28-onboarding-scan", AnyView(OnboardingFlow(step: .scan, draft: draft))),
            ("23-onboarding-targets", AnyView(OnboardingFlow(step: .targets, draft: draft))),
            ("24-launch", AnyView(LaunchScreen().frame(height: 400))),
            ("27-background", AnyView(Color.clear.frame(height: 874))),
        ]

        for (name, view) in screens {
            let content = view
                .environment(model)
                .environment(\.flatScroll, true)
                .frame(width: 402)
                .background { AeroBackground() }
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage, name)
            let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: out.appendingPathComponent(name + ".png"))
        }
    }
}
#endif
