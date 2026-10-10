import Foundation

struct Exercise: Identifiable, Equatable {
    let id: String
    var name: String
    let group: String
    let sets: Int
    let reps: ClosedRange<Int>
    let rpe: Int
    let restSeconds: Int
    let lbs: Int
    var alternative: String
    let about: String

    var repLabel: String { "\(reps.lowerBound)–\(reps.upperBound)" }
    var targetRIR: Int { 10 - rpe }
    var prescription: String { "\(sets) × \(repLabel) · RPE \(rpe)" }
    var lastRecord: String { lbs > 0 ? "\(lbs - 5) × \(reps.upperBound)" : "BW × 9" }
}

struct WorkoutTemplate: Identifiable, Equatable {
    let id: String
    var name: String
    var exercises: [Exercise]
}

struct SetEntry: Equatable {
    var lbs = ""
    var reps = ""
    var rir = ""
    var done = false
}

struct ExerciseProgress: Equatable {
    var sets: [SetEntry]
    var done = false

    init(for exercise: Exercise) {
        sets = Array(repeating: SetEntry(lbs: String(exercise.lbs)), count: exercise.sets)
    }

    /// Total lbs moved across completed sets.
    var volume: Int {
        sets.filter(\.done).reduce(0) { $0 + Int((Double($1.lbs) ?? 0) * (Double($1.reps) ?? 0)) }
    }
}

/// One finished workout, as shown in a template's history.
struct WorkoutSession: Identifiable, Equatable {
    let id: String
    let templateID: String
    let day: Day
    /// Unknown for sessions logged in the app, which does not time workouts yet.
    let minutes: Int?
    let volume: Int
    let sets: Int
    let highlight: String
}

struct DayStatus: Equatable {
    var calories = false
    var workout = false

    var both: Bool { calories && workout }
}
