import Foundation

enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

enum MealSource: Equatable {
    case photo, text
}

struct Meal: Identifiable, Equatable {
    let id: String
    var slot: MealSlot
    var time: String
    var name: String
    var macros: Macros
    var source: MealSource
}

/// One estimated food from a photo or typed entry. Grams are editable; macros follow the grams.
struct FoodItem: Identifiable, Equatable {
    enum Confidence: String {
        case low, medium, high

        var label: String { rawValue.uppercased() }
    }

    let id = UUID()
    var name: String
    var grams: Int
    let baseGrams: Int
    let base: Macros
    var confidence: Confidence

    init(name: String, grams: Int, base: Macros, confidence: Confidence) {
        self.name = name
        self.grams = grams
        self.baseGrams = grams
        self.base = base
        self.confidence = confidence
    }

    var macros: Macros { base.scaled(by: Double(grams) / Double(max(1, baseGrams))) }

    mutating func adjust(by delta: Int) {
        grams = max(10, grams + delta)
    }
}

struct MealRecommendation: Identifiable {
    var id: String { name }
    let name: String
    let kcal: Int
    let protein: Int
    let place: String
    let distance: String
}

enum FoodInput: Equatable {
    case photo
    case text(String)

    var source: MealSource {
        switch self {
        case .photo: .photo
        case .text: .text
        }
    }
}

/// Seam for `/v1/food/analyze` and `/v1/food/parse-text`. An empty list means "no food detected".
protocol FoodAnalyzing {
    func estimate(_ input: FoodInput) async throws -> [FoodItem]
}

/// Stands in for the backend until Slice B's food endpoints are live.
struct MockFoodAnalyzer: FoodAnalyzing {
    var delay: Duration = .milliseconds(1_400)

    func estimate(_ input: FoodInput) async throws -> [FoodItem] {
        try await Task.sleep(for: delay)
        switch input {
        case .photo: return SampleData.photoEstimate
        case .text: return SampleData.textEstimate
        }
    }
}
