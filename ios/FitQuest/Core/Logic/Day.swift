import Foundation

/// A calendar day in the device's local time zone, keyed as `YYYY-MM-DD`.
/// Daily totals and streaks hang off this, so they roll over at local midnight, never UTC.
struct Day: Hashable, Comparable, Codable {
    let key: String

    init(key: String) {
        self.key = key
    }

    init(_ date: Date = .now, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        key = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func < (lhs: Day, rhs: Day) -> Bool { lhs.key < rhs.key }

    func adding(_ days: Int) -> Day {
        Day(Self.math.date(byAdding: .day, value: days, to: date) ?? date, calendar: Self.math)
    }

    func days(since other: Day) -> Int {
        Self.math.dateComponents([.day], from: other.date, to: date).day ?? 0
    }

    func relativeLabel(to today: Day) -> String {
        switch days(since: today) {
        case 0: "TODAY"
        case -1: "YESTERDAY"
        case 1: "TOMORROW"
        case let n where n < 0: "\(-n) DAYS AGO"
        case let n: "IN \(n) DAYS"
        }
    }

    var weekdayShort: String { Self.weekdaysShort[weekdayIndex] }
    var weekdayName: String { Self.weekdayNames[weekdayIndex] }
    var dayOfMonth: String { String(key.suffix(2)) }
    var monthShort: String { Self.months[max(0, min(11, components[1] - 1))] }

    // Day arithmetic runs in UTC so daylight-saving shifts can't skip or repeat a day.
    private static let math: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let weekdaysShort = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    private var components: [Int] {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        return parts.count == 3 ? parts : [1970, 1, 1]
    }

    private var date: Date {
        let parts = components
        return Self.math.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? .distantPast
    }

    private var weekdayIndex: Int { Self.math.component(.weekday, from: date) - 1 }
}
