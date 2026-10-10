import Foundation

/// Demo content lifted from the design prototype. Everything here is replaced by backend data
/// (`/v1/dashboard`, `/v1/plan/generate`, the food endpoints) as those come online.
enum SampleData {
    static let startingXP = 1_340
    static let startingPoints = 340
    static let streakDays = 6

    // MARK: Food

    static func logs(today: Day) -> [Day: [Meal]] {
        func meal(_ id: String, _ slot: MealSlot, _ time: String, _ name: String, _ kcal: Int, _ p: Int, _ c: Int, _ f: Int, _ source: MealSource) -> Meal {
            Meal(id: id, slot: slot, time: time, name: name, macros: Macros(kcal: kcal, protein: p, carbs: c, fat: f), source: source)
        }
        return [
            today: [
                meal("m1", .breakfast, "08:12", "Greek yogurt, berries and granola", 380, 24, 52, 9, .photo),
                meal("m2", .lunch, "12:47", "Chicken and rice bowl", 620, 48, 70, 14, .photo),
                meal("m3", .snack, "16:05", "Apple and almond butter", 200, 5, 25, 10, .text),
            ],
            today.adding(-1): [
                meal("m4", .breakfast, "07:55", "Oats with whey and banana", 520, 38, 78, 9, .photo),
                meal("m5", .lunch, "13:10", "Turkey and avocado wrap", 610, 42, 55, 22, .photo),
                meal("m6", .dinner, "19:30", "Salmon, rice and broccoli", 720, 48, 70, 24, .photo),
                meal("m7", .snack, "21:00", "Cottage cheese", 160, 22, 6, 4, .text),
            ],
            today.adding(-2): [
                meal("m8", .breakfast, "08:20", "Eggs on sourdough toast", 430, 26, 34, 20, .text),
                meal("m9", .lunch, "12:30", "Chicken burrito bowl", 780, 52, 88, 22, .photo),
                meal("m10", .dinner, "19:05", "Tofu stir fry with noodles", 690, 32, 90, 20, .photo),
            ],
        ]
    }

    /// Past days' (calories on target, workout done), newest last.
    static func history(today: Day) -> [Day: DayStatus] {
        let past: [(Bool, Bool)] = [
            (true, true), (true, false), (false, true), (true, true), (true, true),
            (false, false), (true, true), (true, false), (true, true),
        ]
        var result: [Day: DayStatus] = [:]
        for (index, entry) in past.enumerated() {
            result[today.adding(index - past.count)] = DayStatus(calories: entry.0, workout: entry.1)
        }
        return result
    }

    static let recommendations = [
        MealRecommendation(name: "Salmon, quinoa and greens", kcal: 540, protein: 42, place: "Harbor Bowl", distance: "0.4 mi"),
        MealRecommendation(name: "Chicken shawarma plate", kcal: 610, protein: 51, place: "Cedar Grill", distance: "0.7 mi"),
        MealRecommendation(name: "Tofu, edamame and soba", kcal: 480, protein: 34, place: "Kumo Noodle", distance: "1.1 mi"),
        MealRecommendation(name: "Turkey chili with beans", kcal: 450, protein: 38, place: "Franklin St. Kitchen", distance: "0.9 mi"),
    ]

    static var photoEstimate: [FoodItem] {
        [
            FoodItem(name: "Grilled chicken breast", grams: 150, base: Macros(kcal: 248, protein: 46, carbs: 0, fat: 5), confidence: .medium),
            FoodItem(name: "Brown rice", grams: 180, base: Macros(kcal: 202, protein: 5, carbs: 42, fat: 2), confidence: .medium),
            FoodItem(name: "Roasted broccoli", grams: 90, base: Macros(kcal: 50, protein: 3, carbs: 6, fat: 2), confidence: .high),
        ]
    }

    static var textEstimate: [FoodItem] {
        [
            FoodItem(name: "Scrambled eggs (2)", grams: 100, base: Macros(kcal: 148, protein: 12, carbs: 1, fat: 10), confidence: .high),
            FoodItem(name: "Whole wheat toast", grams: 40, base: Macros(kcal: 100, protein: 5, carbs: 17, fat: 1), confidence: .medium),
        ]
    }

    // MARK: Workout

    static let templates: [WorkoutTemplate] = {
        func ex(_ id: String, _ name: String, _ group: String, _ sets: Int, _ reps: ClosedRange<Int>, _ rpe: Int, _ rest: Int, _ lbs: Int, _ alt: String, _ about: String) -> Exercise {
            Exercise(id: id, name: name, group: group, sets: sets, reps: reps, rpe: rpe, restSeconds: rest, lbs: lbs, alternative: alt, about: about)
        }
        return [
            WorkoutTemplate(id: "push", name: "Push day", exercises: [
                ex("bench", "Barbell bench press", "CHEST", 4, 6...8, 8, 120, 155, "Dumbbell bench press", "Retract the shoulder blades and keep feet planted. Lower to mid-chest under control, press back over the shoulders."),
                ex("landmine", "Landmine press", "SHOULDERS", 3, 8...10, 8, 90, 70, "Half-kneeling dumbbell press", "Chosen in place of the overhead barbell press because of your left shoulder. Press up and forward along the bar’s arc."),
                ex("incline", "Incline dumbbell press", "CHEST", 3, 10...12, 8, 90, 50, "Machine incline press", "Bench at 30°. Elbows about 45° from the torso."),
                ex("lateral", "Cable lateral raise", "SHOULDERS", 3, 12...15, 9, 60, 15, "Dumbbell lateral raise", "Lead with the elbow, stop at shoulder height, slow on the way down."),
                ex("pushdown", "Triceps rope pushdown", "TRICEPS", 3, 10...12, 9, 60, 45, "Overhead cable extension", "Pin the elbows to your sides and spread the rope at the bottom."),
            ]),
            WorkoutTemplate(id: "pull", name: "Pull", exercises: [
                ex("row", "Barbell row", "BACK", 4, 6...8, 8, 120, 135, "Chest-supported row", "Hinge to about 45°, pull to the lower ribs."),
                ex("pullup", "Pull-up", "BACK", 3, 6...10, 8, 120, 0, "Lat pulldown", "Full hang at the bottom, chest to the bar."),
                ex("facepull", "Face pull", "SHOULDERS", 3, 12...15, 8, 60, 35, "Reverse fly", "Pull to eye level, rotate the hands back."),
                ex("curl", "Incline dumbbell curl", "BICEPS", 3, 10...12, 9, 60, 25, "Cable curl", "Let the arms hang behind the torso for a full stretch."),
            ]),
            WorkoutTemplate(id: "legs", name: "Legs", exercises: [
                ex("squat", "Back squat", "QUADS", 4, 5...7, 8, 150, 205, "Hack squat", "Brace before each rep, break at hips and knees together."),
                ex("rdl", "Romanian deadlift", "HAMSTRINGS", 3, 8...10, 8, 120, 165, "Hip thrust", "Soft knees, push the hips back until the hamstrings stop you."),
                ex("press", "Leg press", "QUADS", 3, 10...12, 9, 90, 270, "Bulgarian split squat", "Feet shoulder width, do not let the lower back round off the pad."),
                ex("calf", "Standing calf raise", "CALVES", 3, 12...15, 9, 60, 90, "Seated calf raise", "Pause one second at the bottom."),
            ]),
        ]
    }()

    // MARK: Gym

    static let gyms = [
        Gym(id: "ram", name: "Ram Fitness · Chapel Hill", logo: "RF", friendsHere: 3),
        Gym(id: "cs", name: "Carolina Strength Co.", logo: "CS", friendsHere: 1),
    ]

    static let songs: [String: [Song]] = [
        "ram": [
            Song(title: "Tokyo Drift", artist: "Teriyaki Boyz", listeners: ["JK", "MP", "SL"], more: 5),
            Song(title: "Till I Collapse", artist: "Eminem", listeners: ["DR", "AN"], more: 3),
            Song(title: "Can’t Hold Us", artist: "Macklemore & Ryan Lewis", listeners: ["SL", "TW", "JK"], more: 2),
            Song(title: "Stronger", artist: "Kanye West", listeners: ["MP"], more: 4),
            Song(title: "Eye of the Tiger", artist: "Survivor", listeners: ["AN", "DR"], more: 1),
        ],
        "cs": [
            Song(title: "Lose Yourself", artist: "Eminem", listeners: ["TW", "NB"], more: 6),
            Song(title: "POWER", artist: "Kanye West", listeners: ["NB"], more: 2),
            Song(title: "Remember the Name", artist: "Fort Minor", listeners: ["TW"], more: 3),
            Song(title: "Tokyo Drift", artist: "Teriyaki Boyz", listeners: ["CH"], more: 1),
            Song(title: "Seven Nation Army", artist: "The White Stripes", listeners: ["NB", "CH"], more: 0),
        ],
    ]

    static let friends = [
        Friend(initials: "JK", name: "Jordan Kim", gymID: "ram", atGym: true, rank: .c, level: 8, streak: 12, since: "17:20", song: "Tokyo Drift", pet: "Mochi · cat", week: "3/4"),
        Friend(initials: "MP", name: "Maya Patel", gymID: "ram", atGym: true, rank: .b, level: 11, streak: 21, since: "17:45", song: "Stronger", pet: "Atlas · dog", week: "4/5"),
        Friend(initials: "SL", name: "Sam Lee", gymID: "ram", atGym: true, rank: .d, level: 4, streak: 3, since: "18:05", song: "Can’t Hold Us", pet: "Pip · rabbit", week: "2/3"),
        Friend(initials: "DR", name: "Diego Ruiz", gymID: "ram", atGym: false, rank: .c, level: 7, streak: 0, since: nil, song: "Till I Collapse", pet: "Rocco · dog", week: "1/4"),
        Friend(initials: "AN", name: "Ava Nguyen", gymID: "ram", atGym: false, rank: .e, level: 2, streak: 1, since: nil, song: nil, pet: "Bean · hamster", week: "1/3"),
        Friend(initials: "TW", name: "Theo Walsh", gymID: "cs", atGym: true, rank: .a, level: 15, streak: 34, since: "16:50", song: "Lose Yourself", pet: "Duke · dog", week: "5/5"),
        Friend(initials: "NB", name: "Nia Brooks", gymID: "cs", atGym: false, rank: .c, level: 9, streak: 5, since: nil, song: "POWER", pet: "Kiwi · bird", week: "2/4"),
        Friend(initials: "CH", name: "Chris Hall", gymID: "cs", atGym: false, rank: .d, level: 5, streak: 2, since: nil, song: nil, pet: "Toast · cat", week: "2/4"),
    ]
}
