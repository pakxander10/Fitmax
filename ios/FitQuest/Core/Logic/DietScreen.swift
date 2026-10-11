import Foundation

/// A second look at a recipe's own words. Diet labels from a database or an AI are sometimes wrong,
/// so anything that names a forbidden ingredient outright is dropped. This catches the plain cases
/// only: it cannot see an ingredient that is not listed, and gluten is left to the source's label.
enum DietScreen {
    private static let meat: Set<String> = [
        "beef", "pork", "bacon", "ham", "chicken", "turkey", "lamb", "veal", "duck", "sausage", "sausages",
        "prosciutto", "pancetta", "chorizo", "salami", "pepperoni", "steak", "meat", "meatballs", "lard", "gelatin",
    ]
    private static let fish: Set<String> = [
        "fish", "salmon", "tuna", "cod", "anchovy", "anchovies", "sardine", "sardines", "tilapia", "trout", "halibut", "mackerel",
    ]
    private static let shellfish: Set<String> = [
        "shellfish", "shrimp", "shrimps", "prawn", "prawns", "crab", "crabs", "crabmeat", "lobster", "lobsters", "clam", "clams",
        "mussel", "mussels", "oyster", "oysters", "scallop", "scallops", "squid", "calamari", "crayfish", "crawfish",
    ]
    /// Dairy that is never plant-based. "Milk", "butter" and "cream" are left out: coconut milk and peanut butter are fine.
    private static let dairy: Set<String> = [
        "cheese", "parmesan", "mozzarella", "cheddar", "feta", "ricotta", "yogurt", "yoghurt", "ghee", "whey",
    ]
    private static let eggsAndHoney: Set<String> = ["egg", "eggs", "honey", "mayonnaise"]
    private static let nuts: Set<String> = [
        "nut", "nuts", "peanut", "peanuts", "almond", "almonds", "walnut", "walnuts", "pecan", "pecans", "cashew", "cashews",
        "hazelnut", "hazelnuts", "pistachio", "pistachios", "macadamia", "macadamias", "praline", "marzipan", "nutella",
    ]
    private static let pork: Set<String> = ["pork", "bacon", "ham", "prosciutto", "pancetta", "chorizo", "pepperoni", "lard"]
    private static let alcohol: Set<String> = [
        "wine", "beer", "rum", "vodka", "bourbon", "brandy", "whiskey", "whisky", "sake", "mirin", "liqueur", "tequila", "sherry",
    ]

    private static func forbidden(by diet: UserProfile.Diet) -> Set<String> {
        switch diet {
        case .vegetarian: meat.union(fish).union(shellfish)
        case .vegan: meat.union(fish).union(shellfish).union(dairy).union(eggsAndHoney)
        case .pescatarian: meat
        case .halal: pork.union(alcohol).union(["gelatin"])
        case .kosher: pork.union(shellfish)
        case .glutenFree: []
        case .dairyFree: dairy
        case .nutAllergy: nuts
        case .shellfishAllergy: shellfish
        }
    }

    /// False when any of the texts (a title, ingredient names) contains a word the diet rules out.
    /// Whole words only, so "butternut", "nutmeg" and "eggplant" pass.
    static func passes(_ diet: [UserProfile.Diet], texts: [String]) -> Bool {
        let banned = diet.reduce(into: Set<String>()) { $0.formUnion(forbidden(by: $1)) }
        guard !banned.isEmpty else { return true }
        let words = texts.flatMap { $0.lowercased().split { !$0.isLetter }.map(String.init) }
        return banned.isDisjoint(with: words)
    }
}
