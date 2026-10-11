import Foundation

/// One full-body photo plus the profile numbers the scan needs to scale the body.
struct ScanRequest: Equatable {
    /// JPEG. Sent once and never kept.
    let photo: Data
    let heightCm: Double
    let weightKg: Double?
    let sex: UserProfile.Sex
}

enum ScanError: Error, Equatable {
    /// No scan server address is set up in this build.
    case notConfigured
    case notSignedIn
    case noPerson
    case badPhoto
    /// The server is off, asleep or failed. Colab shuts down often, so this is expected.
    case unavailable

    var message: String {
        switch self {
        case .notConfigured: "Body scanning isn’t set up in this build yet."
        case .notSignedIn: "Couldn’t confirm your sign-in. Close the app, open it again, and retry."
        case .noPerson: "No person found. Stand fully in frame, head to feet, and try again."
        case .badPhoto: "That photo couldn’t be read. Take a new one."
        case .unavailable: "The scan server is offline right now. Try again in a few minutes."
        }
    }
}

/// Turns a photo into body measurements. The SAM 3D worker is one conformance; an on-device
/// scan can be another, used when the worker is down.
protocol BodyScanning {
    func scan(_ request: ScanRequest) async throws -> Biometrics
}
