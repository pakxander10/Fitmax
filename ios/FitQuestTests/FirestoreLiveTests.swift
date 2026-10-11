#if os(iOS)
import XCTest
@testable import FitQuest

/// Writes one meal to the real Firestore database, reads it back and deletes it.
/// Opt-in, and only meaningful inside the app with GoogleService-Info.plist present:
/// `TEST_RUNNER_FQ_LIVE_FIRESTORE=1 xcodebuild test -only-testing:FitQuestTests/FirestoreLiveTests ...`
final class FirestoreLiveTests: XCTestCase {
    private struct TimedOut: Error {}

    func testAMealRoundTripsThroughFirestore() async throws {
        guard ProcessInfo.processInfo.environment["FQ_LIVE_FIRESTORE"] != nil else {
            throw XCTSkip("Set FQ_LIVE_FIRESTORE to write to the real database")
        }
        let store = FirestoreMealStore()
        let day = Day(key: "2000-01-01")
        let meal = Meal(
            id: "diagnostic-\(UUID().uuidString)", slot: .snack, time: "00:00", name: "Connection check",
            macros: Macros(kcal: 1, protein: 0, carbs: 0, fat: 0), source: .text
        )

        try await withTimeout { try await store.save(meal, on: day, for: "diagnostic") }
        print("FIRESTORE: write accepted")
        let read = try await withTimeout { try await store.meals(for: "diagnostic") }
        print("FIRESTORE: read back \(read[day]?.count ?? 0) meal(s)")
        try await withTimeout { try await store.remove(meal.id) }
        print("FIRESTORE: diagnostic meal deleted")

        XCTAssertEqual(read[day]?.contains(meal), true)
    }

    /// Firestore waits indefinitely while offline, so give up after a while instead of hanging the run.
    private func withTimeout<T>(_ work: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: .seconds(20))
                throw TimedOut()
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}
#endif
