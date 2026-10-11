import Foundation

/// US Navy body-fat estimate (Hodgdon & Beckett, 1984), the same formula the scan worker uses.
/// Inputs are cm; the formula itself works in inches. The result is an estimate, not a clinical reading.
enum Navy {
    /// Outside this range the inputs are almost certainly a bad scan, not a real body.
    static let plausiblePercent = 2.0...70.0

    /// Body-fat percentage to one decimal, or nil when an input is missing or impossible.
    static func bodyFat(sex: UserProfile.Sex, heightCm: Double, neckCm: Double?, waistCm: Double?, hipsCm: Double?) -> Double? {
        guard let neckCm, let waistCm, heightCm > 0 else { return nil }
        let inch = UserProfile.cmPerInch
        let height = heightCm / inch, neck = neckCm / inch, waist = waistCm / inch

        let percent: Double
        switch sex {
        case .male:
            guard waist > neck else { return nil }
            percent = 86.010 * log10(waist - neck) - 70.041 * log10(height) + 36.76
        case .female:
            guard let hipsCm else { return nil }
            let hips = hipsCm / inch
            guard waist + hips > neck else { return nil }
            percent = 163.205 * log10(waist + hips - neck) - 97.684 * log10(height) - 78.387
        }
        guard plausiblePercent.contains(percent) else { return nil }
        return (percent * 10).rounded() / 10
    }
}
