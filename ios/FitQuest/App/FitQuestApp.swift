import SwiftUI

@main
struct FitQuestApp: App {
    private let foodAnalyzer: FoodAnalyzing?
    private let mealStore: MealStoring?
    private let bodyScanner: BodyScanning?

    init() {
        let hasFirebase = FirebaseSetup.configure()
        foodAnalyzer = hasFirebase ? FirebaseFoodAnalyzer() : nil
        // Meals are always kept on the phone; with Firebase they are copied to Firestore as well.
        mealStore = hasFirebase ? MirroredMealStore(local: LocalMealStore(), remote: FirestoreMealStore()) : nil
        // The scan worker only accepts a Firebase ID token, so scanning needs Firebase too.
        bodyScanner = hasFirebase ? WorkerBodyScanner.fromConfig(idToken: FirebaseSetup.idToken) : nil
    }

    var body: some Scene {
        WindowGroup {
            RootView(foodAnalyzer: foodAnalyzer, mealStore: mealStore, bodyScanner: bodyScanner)
                .task { await FirebaseSetup.signInIfNeeded() }
        }
    }
}
