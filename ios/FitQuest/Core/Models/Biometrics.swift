import Foundation

/// One body scan, in the shape the scan worker returns (PROJECT_CONTEXT.md 7.1).
/// Every number is an estimate from a photo, and any of them may be missing.
struct Biometrics: Equatable, Codable {
    enum Method: String, Codable { case sam3d, visionNavy = "vision_navy", manual }
    enum Confidence: String, Codable { case low, medium, high }

    /// The measurements a person can correct after a scan. Raw values are the stored field names.
    enum Field: String, CaseIterable, Identifiable, Codable {
        case neck = "neck_cm", chest = "chest_cm", waist = "waist_cm", hips = "hips_cm"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .neck: "Neck"
            case .chest: "Chest"
            case .waist: "Waist"
            case .hips: "Hips"
            }
        }
    }

    var method: Method
    var confidence: Confidence
    var heightCm: Double
    var weightKg: Double?
    var sex: UserProfile.Sex
    var neckCm: Double?
    var chestCm: Double?
    var waistCm: Double?
    var hipsCm: Double?
    var bodyFatPct: Double?
    var bodyFatMethod: String?
    var measuredAt: Date
    var userEditedFields: [String]

    enum CodingKeys: String, CodingKey {
        case method, confidence, sex
        case heightCm = "height_cm", weightKg = "weight_kg"
        case neckCm = "neck_cm", chestCm = "chest_cm", waistCm = "waist_cm", hipsCm = "hips_cm"
        case bodyFatPct = "body_fat_pct", bodyFatMethod = "body_fat_method"
        case measuredAt = "measured_at", userEditedFields = "user_edited_fields"
    }

    func value(of field: Field) -> Double? {
        switch field {
        case .neck: neckCm
        case .chest: chestCm
        case .waist: waistCm
        case .hips: hipsCm
        }
    }

    /// A copy with one measurement corrected by hand. Body fat is worked out again from the new
    /// numbers, and the field is remembered as edited.
    func editing(_ field: Field, cm: Double) -> Biometrics {
        var copy = self
        switch field {
        case .neck: copy.neckCm = cm
        case .chest: copy.chestCm = cm
        case .waist: copy.waistCm = cm
        case .hips: copy.hipsCm = cm
        }
        if !copy.userEditedFields.contains(field.rawValue) {
            copy.userEditedFields.append(field.rawValue)
        }
        copy.bodyFatPct = Navy.bodyFat(
            sex: sex, heightCm: heightCm, neckCm: copy.neckCm, waistCm: copy.waistCm, hipsCm: copy.hipsCm
        )
        copy.bodyFatMethod = "navy"
        return copy
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
