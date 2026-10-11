import Foundation

/// Who is signed in. `id` is the auth provider's user id and keys everything stored for them.
struct Account: Equatable, Codable {
    let id: String
    var name: String
    var email: String

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    /// First and last initial, or the first letter of the email when there is no name.
    var initials: String {
        let words = name.split(separator: " ")
        let letters = words.count > 1 ? [words.first, words.last] : [words.first]
        let initials = letters.compactMap { $0?.first }.map(String.init).joined().uppercased()
        return initials.isEmpty ? email.prefix(1).uppercased() : initials
    }
}

/// What onboarding collects. Raw values and coding keys are the stored field names.
/// Height and weight are stored in metric, which the formulas use, and shown in feet, inches and pounds.
struct UserProfile: Equatable, Codable {
    enum Sex: String, Codable, CaseIterable, Identifiable {
        case male, female

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    enum Goal: String, Codable, CaseIterable, Identifiable {
        case cut, maintain, leanBulk = "lean_bulk"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .cut: "Lose fat"
            case .maintain: "Maintain"
            case .leanBulk: "Build muscle"
            }
        }

        var detail: String {
            switch self {
            case .cut: "Eat a little under what you burn"
            case .maintain: "Eat about what you burn"
            case .leanBulk: "Eat a little over what you burn"
            }
        }
    }

    enum Experience: String, Codable, CaseIterable, Identifiable {
        case beginner, intermediate, advanced

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    enum Injury: String, Codable, CaseIterable, Identifiable {
        case shoulder, elbow, wrist, lowerBack = "lower_back", hip, knee, ankle

        var id: String { rawValue }

        var label: String {
            switch self {
            case .lowerBack: "Lower back"
            default: rawValue.capitalized
            }
        }
    }

    enum Equipment: String, Codable, CaseIterable, Identifiable {
        case barbell, dumbbells, cables, machines, pullupBar = "pullup_bar", kettlebells, bands

        var id: String { rawValue }

        var label: String {
            switch self {
            case .pullupBar: "Pull-up bar"
            default: rawValue.capitalized
            }
        }
    }

    enum Diet: String, Codable, CaseIterable, Identifiable {
        case vegetarian, vegan, pescatarian, halal, kosher
        case glutenFree = "gluten_free", dairyFree = "dairy_free"
        case nutAllergy = "nut_allergy", shellfishAllergy = "shellfish_allergy"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .glutenFree: "Gluten-free"
            case .dairyFree: "Dairy-free"
            case .nutAllergy: "Nut allergy"
            case .shellfishAllergy: "Shellfish allergy"
            default: rawValue.capitalized
            }
        }

        /// The restriction spelled out, for the meal-ideas prompt.
        var rule: String {
            switch self {
            case .vegetarian: "Vegetarian: no meat, poultry, fish or seafood."
            case .vegan: "Vegan: no animal products at all, including dairy, eggs and honey."
            case .pescatarian: "Pescatarian: no meat or poultry; fish and seafood are fine."
            case .halal: "Halal: no pork or alcohol, and any meat must be halal."
            case .kosher: "Kosher: no pork or shellfish, and no meat together with dairy."
            case .glutenFree: "Gluten-free: no wheat, barley, rye or anything made from them."
            case .dairyFree: "Dairy-free: no milk, cheese, butter, cream or yoghurt."
            case .nutAllergy: "Nut allergy: no peanuts or tree nuts, and no nut oils or nut butters."
            case .shellfishAllergy: "Shellfish allergy: no prawns, crab, lobster, clams, mussels, oysters or squid."
            }
        }
    }

    static let defaultPetName = "Biscuit"
    /// Long enough for a name, short enough for the pet's card title.
    static let maxPetNameLength = 20

    static let ageRange = 13...100
    static let daysRange = 1...7
    static let cmPerInch = 2.54
    static let kgPerPound = 0.45359237

    var sex: Sex
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var goal: Goal
    var experience: Experience
    var daysPerWeek: Int
    var injuries: Set<Injury>
    var equipment: Set<Equipment>
    var diet: Set<Diet> = []
    var petName = UserProfile.defaultPetName

    enum CodingKeys: String, CodingKey {
        case sex, age, goal, experience, injuries, equipment
        case heightCm = "height_cm", weightKg = "weight_kg", daysPerWeek = "days_per_week"
        case diet = "dietary_restrictions", petName = "pet_name"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sex, forKey: .sex)
        try container.encode(age, forKey: .age)
        try container.encode(heightCm, forKey: .heightCm)
        try container.encode(weightKg, forKey: .weightKg)
        try container.encode(goal, forKey: .goal)
        try container.encode(experience, forKey: .experience)
        try container.encode(daysPerWeek, forKey: .daysPerWeek)
        // A set has no order; store the lists the same way every time.
        try container.encode(Injury.allCases.filter(injuries.contains), forKey: .injuries)
        try container.encode(Equipment.allCases.filter(equipment.contains), forKey: .equipment)
        try container.encode(dietList, forKey: .diet)
        try container.encode(petName, forKey: .petName)
    }

    /// The restrictions in a fixed order.
    var dietList: [Diet] { Diet.allCases.filter(diet.contains) }

    /// Height to the nearest inch, as "5′10″".
    var heightText: String {
        let inches = Int((heightCm / Self.cmPerInch).rounded())
        return "\(inches / 12)′\(inches % 12)″"
    }

    /// Weight in pounds, as "165" or "165.3".
    var weightText: String { Self.figure(weightKg / Self.kgPerPound) }

    /// A number to one decimal place at most: "165" for whole values, "165.3" otherwise.
    static func figure(_ value: Double) -> String {
        let tenths = (value * 10).rounded() / 10
        return tenths == tenths.rounded() ? String(Int(tenths)) : String(format: "%.1f", tenths)
    }

    var goalSummary: String { "\(goal.label) · \(daysPerWeek) \(daysPerWeek == 1 ? "day" : "days") a week" }
    var injurySummary: String { Self.sentence(Injury.allCases.filter(injuries.contains).map(\.label), empty: "None") }
    var equipmentSummary: String { Self.sentence(Equipment.allCases.filter(equipment.contains).map(\.label), empty: "Bodyweight only") }
    var dietSummary: String { Self.sentence(dietList.map(\.label), empty: "No restrictions") }

    /// "Barbell, dumbbells, pull-up bar": a list with only its first word capitalised.
    private static func sentence(_ labels: [String], empty: String) -> String {
        guard let first = labels.first else { return empty }
        return ([first] + labels.dropFirst().map { $0.lowercased() }).joined(separator: ", ")
    }
}

// In an extension so the memberwise initialiser survives.
extension UserProfile {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sex = try container.decode(Sex.self, forKey: .sex)
        age = try container.decode(Int.self, forKey: .age)
        heightCm = try container.decode(Double.self, forKey: .heightCm)
        weightKg = try container.decode(Double.self, forKey: .weightKg)
        goal = try container.decode(Goal.self, forKey: .goal)
        experience = try container.decode(Experience.self, forKey: .experience)
        daysPerWeek = try container.decode(Int.self, forKey: .daysPerWeek)
        injuries = try container.decode(Set<Injury>.self, forKey: .injuries)
        equipment = try container.decode(Set<Equipment>.self, forKey: .equipment)
        // Absent from profiles saved before onboarding asked about diet.
        diet = try container.decodeIfPresent(Set<Diet>.self, forKey: .diet) ?? []
        // Absent from profiles saved before pets could be named.
        petName = try container.decodeIfPresent(String.self, forKey: .petName) ?? UserProfile.defaultPetName
    }
}

/// The onboarding form as typed, before it is known to be a valid profile.
struct ProfileDraft: Equatable {
    /// Shortest and tallest height accepted, in inches: 3 ft 4 in to 8 ft 2 in.
    static let heightInchesRange = 40.0...98.0
    static let weightPoundsRange = 66.0...660.0

    var sex: UserProfile.Sex?
    var age = ""
    /// Pounds.
    var weight = ""
    var heightFeet = ""
    /// May be left blank for an exact number of feet.
    var heightInches = ""
    var goal: UserProfile.Goal?
    var experience: UserProfile.Experience?
    var daysPerWeek = 3
    var injuries: Set<UserProfile.Injury> = []
    var equipment: Set<UserProfile.Equipment> = []
    var diet: Set<UserProfile.Diet> = []
    /// Blank keeps the default name.
    var petName = ""

    init() {}

    /// Prefills the form from a saved profile.
    init(_ profile: UserProfile) {
        sex = profile.sex
        age = String(profile.age)
        weight = profile.weightText
        // Rounded to a tenth of an inch first, so 5 ft 10 in comes back as exactly that.
        let inches = (profile.heightCm / UserProfile.cmPerInch * 10).rounded() / 10
        let feet = (inches / 12).rounded(.down)
        heightFeet = String(Int(feet))
        heightInches = UserProfile.figure(inches - feet * 12)
        goal = profile.goal
        experience = profile.experience
        daysPerWeek = profile.daysPerWeek
        injuries = profile.injuries
        equipment = profile.equipment
        diet = profile.diet
        petName = profile.petName
    }

    /// The first thing wrong with the "about you" step, top of the form first. Nil when it is complete.
    var bodyProblem: String? {
        if sex == nil { return "Choose your sex." }
        if parsedAge == nil { return "Enter your age (13 to 100)." }
        if parsedPounds == nil { return "Enter your weight in pounds (66 to 660)." }
        if parsedInches == nil { return "Enter your height, from 3 ft 4 in to 8 ft 2 in." }
        return nil
    }

    /// The first thing wrong with the goal step. Nil when it is complete.
    var goalProblem: String? {
        if goal == nil { return "Choose a goal." }
        if experience == nil { return "Choose your experience level." }
        return nil
    }

    /// The finished profile, once every required answer is in range.
    var profile: UserProfile? {
        guard let sex, let age = parsedAge, let inches = parsedInches, let pounds = parsedPounds,
              let goal, let experience else { return nil }
        return UserProfile(
            sex: sex, age: age, heightCm: inches * UserProfile.cmPerInch, weightKg: pounds * UserProfile.kgPerPound,
            goal: goal, experience: experience,
            daysPerWeek: min(max(daysPerWeek, UserProfile.daysRange.lowerBound), UserProfile.daysRange.upperBound),
            injuries: injuries, equipment: equipment, diet: diet, petName: tidyPetName
        )
    }

    private var parsedAge: Int? {
        Int(age.trimmingCharacters(in: .whitespaces)).flatMap { UserProfile.ageRange.contains($0) ? $0 : nil }
    }

    private var parsedPounds: Double? {
        FoodItem.parseAmount(weight).flatMap { Self.weightPoundsRange.contains($0) ? $0 : nil }
    }

    /// Whole feet plus inches under 12, as total inches.
    private var parsedInches: Double? {
        guard let feet = Int(heightFeet.trimmingCharacters(in: .whitespaces)) else { return nil }
        let blank = heightInches.trimmingCharacters(in: .whitespaces).isEmpty
        guard let inches = blank ? 0 : FoodItem.parseAmount(heightInches), (0..<12).contains(inches) else { return nil }
        let total = Double(feet) * 12 + inches
        return Self.heightInchesRange.contains(total) ? total : nil
    }

    /// Trimmed and cut to length; "Biscuit" when nothing was typed.
    private var tidyPetName: String {
        let name = String(petName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(UserProfile.maxPetNameLength))
            .trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? UserProfile.defaultPetName : name
    }

    var hasAllEquipment: Bool { equipment.count == UserProfile.Equipment.allCases.count }

    /// Picks every piece of equipment, or clears the list when everything is already picked.
    mutating func toggleAllEquipment() {
        equipment = hasAllEquipment ? [] : Set(UserProfile.Equipment.allCases)
    }
}
