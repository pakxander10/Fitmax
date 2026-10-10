#if os(macOS)
import SwiftUI
import XCTest
@testable import FitQuest

/// Renders each screen to a PNG so layouts can be checked without a simulator.
/// Opt-in: `FQ_RENDER_DIR=/some/dir swift test --filter RenderTests`
final class RenderTests: XCTestCase {
    @MainActor
    func testRenderScreens() throws {
        guard let dir = ProcessInfo.processInfo.environment["FQ_RENDER_DIR"] else {
            throw XCTSkip("Set FQ_RENDER_DIR to render screens")
        }
        let out = URL(fileURLWithPath: dir, isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let model = AppModel(today: Day(key: "2026-10-10"))
        let meal = try XCTUnwrap(model.logs[model.today]?[1])
        let friend = SampleData.friends[1]
        let bench = try XCTUnwrap(model.activeTemplate?.exercises.first)
        model.toggleSet(0, of: bench)

        let screens: [(String, AnyView)] = [
            ("01-calorie", AnyView(PageScroll { CaloriePage() })),
            ("02-dashboard", AnyView(PageScroll { DashboardPage() })),
            ("03-workout", AnyView(PageScroll { WorkoutPage() })),
            ("04-gym", AnyView(PageScroll { GymPage() })),
            ("05-meal-detail", AnyView(MealDetail(meal: meal, day: model.today))),
            ("06-log-meal-capture", AnyView(LogMealFlow())),
            ("07-log-meal-review", AnyView(LogMealFlow(previewItems: SampleData.photoEstimate))),
            ("08-profile", AnyView(ProfileSheet())),
            ("09-pet", AnyView(PetSheet())),
            ("10-friend", AnyView(FriendProfile(friend: friend))),
            ("11-exercise", AnyView(ExerciseDetail(initialID: bench.id))),
            ("12-about-exercise", AnyView(AboutExerciseCard(exercise: bench))),
            ("13-nav", AnyView(NavBar().frame(height: 120))),
        ]

        for (name, view) in screens {
            let content = view
                .environment(model)
                .environment(\.flatScroll, true)
                .frame(width: 402)
                .background(Theme.canvas)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.cgImage, name)
            let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: out.appendingPathComponent(name + ".png"))
        }
    }
}
#endif
