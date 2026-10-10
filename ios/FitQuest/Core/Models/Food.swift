import Foundation

enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
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

/// A natural unit for a food: one egg, one slice, one cup.
struct Serving: Equatable {
    let name: String
    let grams: Double
}

enum AmountUnit: Equatable {
    case grams, servings
}

/// One estimated food from a photo or typed entry. The portion is editable, in grams or,
/// where the food has a natural serving, in servings; macros follow the portion.
struct FoodItem: Identifiable, Equatable {
    enum Confidence: String {
        case low, medium, high

        var label: String { rawValue.capitalized }
    }

    static let maxGrams: Double = 5_000

    let id = UUID()
    var name: String
    private(set) var grams: Double
    let baseGrams: Double
    let base: Macros
    var confidence: Confidence
    let serving: Serving?
    /// Which unit the portion is shown and edited in. Servings only when `serving` is known.
    private(set) var unit = AmountUnit.grams

    init(name: String, grams: Double, base: Macros, confidence: Confidence, serving: Serving? = nil) {
        self.name = name
        self.grams = grams
        self.baseGrams = grams
        self.base = base
        self.confidence = confidence
        self.serving = serving
    }

    var macros: Macros { base.scaled(by: grams / max(1, baseGrams)) }

    /// The portion in the current unit.
    var amount: Double {
        if unit == .servings, let serving { return grams / serving.grams }
        return grams
    }

    /// The portion as shown in the amount field: whole grams, or servings to two decimals.
    var amountText: String {
        let decimals = unit == .servings ? 2 : 0
        return amount.formatted(.number.precision(.fractionLength(0...decimals)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }

    mutating func setUnit(_ unit: AmountUnit) {
        guard unit == .grams || serving != nil else { return }
        self.unit = unit
    }

    /// Sets the portion from a typed value in the current unit. Zero, negative and non-numbers are ignored.
    mutating func setAmount(_ value: Double) {
        guard value.isFinite, value > 0 else { return }
        let perUnit = unit == .servings ? (serving?.grams ?? 1) : 1
        grams = min(value * perUnit, Self.maxGrams)
    }

    /// Nudges the portion by 10 g, or half a serving. A step that would empty the portion is ignored.
    mutating func step(_ direction: Int) {
        let next = amount + Double(direction) * (unit == .servings ? 0.5 : 10)
        setAmount(next)
    }

    /// Reads what someone typed into the amount field, accepting a decimal comma.
    static func parseAmount(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
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
    case photo(Data)
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
