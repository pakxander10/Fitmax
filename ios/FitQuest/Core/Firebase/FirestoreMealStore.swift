import FirebaseAuth
import FirebaseFirestore

/// Meals in Firestore at `users/{uid}/meals/{mealId}`, the layout in PROJECT_CONTEXT.md section 4.
/// `uid` is the Firebase user, so security rules can keep each person's meals to themselves.
struct FirestoreMealStore: MealStoring {
    enum StoreError: Error { case notSignedIn }

    /// The signed-in user's meals. Signs in first if the launch-time sign-in has not finished or failed.
    private func collection() async throws -> CollectionReference {
        await FirebaseSetup.signInIfNeeded()
        guard let uid = Auth.auth().currentUser?.uid else { throw StoreError.notSignedIn }
        return Firestore.firestore().collection("users").document(uid).collection("meals")
    }

    func meals(for accountID: String) async throws -> [Day: [Meal]] {
        let snapshot = try await collection().whereField("account", isEqualTo: accountID).getDocuments()
        return StoredMeal.grouped(snapshot.documents.compactMap { StoredMeal(fields: $0.data()) })
    }

    func save(_ meal: Meal, on day: Day, for accountID: String) async throws {
        try await collection().document(meal.id).setData(StoredMeal(meal, day: day, accountID: accountID).fields)
    }

    func remove(_ mealID: String) async throws {
        try await collection().document(mealID).delete()
    }
}
