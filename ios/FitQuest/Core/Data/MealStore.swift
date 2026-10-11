import Foundation
import OSLog

/// Where logged meals are kept between launches.
protocol MealStoring {
    /// Every meal this account has logged, by day, in the order they were logged.
    func meals(for accountID: String) async throws -> [Day: [Meal]]
    /// Saves a meal, replacing any earlier copy with the same id.
    func save(_ meal: Meal, on day: Day, for accountID: String) async throws
}

/// A meal as it is written to storage. Field names follow the project's Firestore layout
/// (`users/{uid}/meals/{mealId}`); `account` is added because one phone can hold several accounts.
struct StoredMeal: Codable, Equatable {
    var id: String
    var account: String
    var day: String
    var slot: String
    var time: String
    var name: String
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var source: String

    init(_ meal: Meal, day: Day, accountID: String) {
        id = meal.id
        account = accountID
        self.day = day.key
        slot = meal.slot.rawValue
        time = meal.time
        name = meal.name
        kcal = meal.macros.kcal
        protein = meal.macros.protein
        carbs = meal.macros.carbs
        fat = meal.macros.fat
        source = meal.source.rawValue
    }

    /// Reads a stored document. Nil when a field is missing or of the wrong type.
    init?(fields: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(fields),
              let data = try? JSONSerialization.data(withJSONObject: fields),
              let stored = try? JSONDecoder().decode(StoredMeal.self, from: data) else { return nil }
        self = stored
    }

    /// The same values as a plain dictionary, for document stores.
    var fields: [String: Any] {
        [
            "id": id, "account": account, "day": day, "slot": slot, "time": time, "name": name,
            "kcal": kcal, "protein": protein, "carbs": carbs, "fat": fat, "source": source,
        ]
    }

    var dayValue: Day { Day(key: day) }

    /// Unknown slots and sources from a newer or older build fall back to something sensible.
    var meal: Meal {
        Meal(
            id: id, slot: MealSlot(rawValue: slot) ?? .snack, time: time, name: name,
            macros: Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat),
            source: MealSource(rawValue: source) ?? .text
        )
    }

    static func grouped(_ stored: [StoredMeal]) -> [Day: [Meal]] {
        stored.reduce(into: [:]) { $0[$1.dayValue, default: []].append($1.meal) }
    }
}

/// Meals kept on this phone. This is the copy the app reads, so logging works with no network.
final class LocalMealStore: MealStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func meals(for accountID: String) async throws -> [Day: [Meal]] {
        StoredMeal.grouped(stored(for: accountID))
    }

    func save(_ meal: Meal, on day: Day, for accountID: String) async throws {
        var all = stored(for: accountID)
        let entry = StoredMeal(meal, day: day, accountID: accountID)
        if let index = all.firstIndex(where: { $0.id == meal.id }) {
            all[index] = entry
        } else {
            all.append(entry)
        }
        defaults.set(try JSONEncoder().encode(all), forKey: Self.key(accountID))
    }

    private func stored(for accountID: String) -> [StoredMeal] {
        defaults.data(forKey: Self.key(accountID)).flatMap { try? JSONDecoder().decode([StoredMeal].self, from: $0) } ?? []
    }

    private static func key(_ accountID: String) -> String { "fq-meals-\(accountID)" }
}

/// Saves on the phone first, then sends a copy to a second store (Firestore) in the background.
/// The phone's copy is the one read back, so a cloud that is offline or refusing never loses a meal.
final class MirroredMealStore: MealStoring {
    private static let log = Logger(subsystem: "com.adharsh.fitquest", category: "meals")

    private let local: MealStoring
    private let remote: MealStoring
    private var copies: Task<Void, Never>?
    /// Accounts whose saved meals have been re-sent to the cloud since the app started.
    private var caughtUp: Set<String> = []

    init(local: MealStoring, remote: MealStoring) {
        self.local = local
        self.remote = remote
    }

    func meals(for accountID: String) async throws -> [Day: [Meal]] {
        let meals = try await local.meals(for: accountID)
        // Once per launch, send everything again: a meal logged while the cloud was unreachable is
        // otherwise never copied. Saving the same meal twice just overwrites it.
        if caughtUp.insert(accountID).inserted {
            for day in meals.keys.sorted() {
                for meal in meals[day] ?? [] { copy(meal, on: day, for: accountID) }
            }
        }
        return meals
    }

    func save(_ meal: Meal, on day: Day, for accountID: String) async throws {
        try await local.save(meal, on: day, for: accountID)
        copy(meal, on: day, for: accountID)
    }

    /// Queues one meal for the cloud, after any already waiting.
    private func copy(_ meal: Meal, on day: Day, for accountID: String) {
        copies = Task { [remote, previous = copies] in
            await previous?.value
            do {
                try await remote.save(meal, on: day, for: accountID)
            } catch {
                Self.log.error("Cloud copy of a meal failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Waits for the cloud copies sent so far. For tests.
    func remoteCopies() async {
        await copies?.value
    }
}
