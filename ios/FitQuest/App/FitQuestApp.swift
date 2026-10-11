import SwiftUI

@main
struct FitQuestApp: App {
    private let foodAnalyzer: FoodAnalyzing?

    init() {
        foodAnalyzer = FirebaseSetup.configure() ? FirebaseFoodAnalyzer() : nil
    }

    var body: some Scene {
        WindowGroup {
            RootView(foodAnalyzer: foodAnalyzer)
                .task { await FirebaseSetup.signInIfNeeded() }
        }
    }
}
