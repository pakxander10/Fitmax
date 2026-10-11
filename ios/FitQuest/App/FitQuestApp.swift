import SwiftUI

@main
struct FitQuestApp: App {
    private let foodAnalyzer: FoodAnalyzing?
    private let bodyScanner: BodyScanning?

    init() {
        let hasFirebase = FirebaseSetup.configure()
        foodAnalyzer = hasFirebase ? FirebaseFoodAnalyzer() : nil
        // The scan worker only accepts a Firebase ID token, so scanning needs Firebase too.
        bodyScanner = hasFirebase ? WorkerBodyScanner.fromConfig(idToken: FirebaseSetup.idToken) : nil
    }

    var body: some Scene {
        WindowGroup {
            RootView(foodAnalyzer: foodAnalyzer, bodyScanner: bodyScanner)
                .task { await FirebaseSetup.signInIfNeeded() }
        }
    }
}
