import XCTest
@testable import FitQuest

final class DayTests: XCTestCase {
    func testAddingDaysCrossesMonthBoundaries() {
        XCTAssertEqual(Day(key: "2026-10-31").adding(1), Day(key: "2026-11-01"))
        XCTAssertEqual(Day(key: "2026-03-01").adding(-1), Day(key: "2026-02-28"))
        XCTAssertEqual(Day(key: "2026-10-10").adding(-9), Day(key: "2026-10-01"))
    }

    // feature_calorie.md risk: daily totals use the device's local midnight, not UTC.
    func testDayUsesLocalMidnightNotUTC() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        // 23:30 on 10 Oct in New York is already 03:30 on 11 Oct in UTC.
        let lateEvening = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-11T03:30:00Z"))
        XCTAssertEqual(Day(lateEvening, calendar: newYork), Day(key: "2026-10-10"))
    }

    func testRelativeLabels() {
        let today = Day(key: "2026-10-10")
        XCTAssertEqual(today.relativeLabel(to: today), "Today")
        XCTAssertEqual(today.adding(-1).relativeLabel(to: today), "Yesterday")
        XCTAssertEqual(today.adding(1).relativeLabel(to: today), "Tomorrow")
        XCTAssertEqual(today.adding(-3).relativeLabel(to: today), "3 days ago")
        XCTAssertEqual(today.adding(2).relativeLabel(to: today), "In 2 days")
    }

    func testDisplayParts() {
        let day = Day(key: "2026-10-03")
        XCTAssertEqual(day.weekdayShort, "Sat")
        XCTAssertEqual(day.weekdayName, "Saturday")
        XCTAssertEqual(day.dayOfMonth, "03")
        XCTAssertEqual(day.monthShort, "Oct")
    }

    func testOrdering() {
        XCTAssertLessThan(Day(key: "2026-09-30"), Day(key: "2026-10-01"))
    }
}
