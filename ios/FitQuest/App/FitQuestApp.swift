import SwiftUI

@main
struct FitQuestApp: App {
    private let foodAnalyzer: FoodAnalyzing?
    private let mealStore: MealStoring?

    init() {
        let firebase = FirebaseSetup.configure()
        foodAnalyzer = firebase ? FirebaseFoodAnalyzer() : nil
        // Meals are always kept on the phone; with Firebase they are copied to Firestore as well.
        mealStore = firebase ? MirroredMealStore(local: LocalMealStore(), remote: FirestoreMealStore()) : nil
    }

    var body: some Scene {
        WindowGroup {
            RootView(foodAnalyzer: foodAnalyzer, mealStore: mealStore)
                .task { await FirebaseSetup.signInIfNeeded() }
        }
    }
}
