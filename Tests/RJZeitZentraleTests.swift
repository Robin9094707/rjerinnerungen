import XCTest
@testable import RJZeitZentrale

final class RJZeitZentraleTests: XCTestCase {
    func testDurationFormatting() {
        XCTAssertEqual(DurationFormat.clock(65), "01:05")
        XCTAssertEqual(DurationFormat.clock(3_661), "1:01:01")
        XCTAssertEqual(DurationFormat.compact(1_500), "25 min")
    }

    func testReminderDailyOccurrenceAfterDueDate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let due = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 9)))
        let later = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 12)))
        let item = ReminderItem(title: "Test", dueDate: due, recurrence: .daily)
        XCTAssertTrue(item.occurs(on: later, calendar: calendar))
    }

    func testOneTimeReminderDoesNotRepeat() throws {
        let calendar = Calendar(identifier: .gregorian)
        let due = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 9)))
        let later = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 9)))
        let item = ReminderItem(title: "Einmalig", dueDate: due, recurrence: .never)
        XCTAssertFalse(item.occurs(on: later, calendar: calendar))
    }

    func testSingleAlarmReturnsFutureDate() throws {
        let future = Date.now.addingTimeInterval(3_600)
        let alarm = AlarmRecord(title: "Test", fireDate: future)
        XCTAssertEqual(try XCTUnwrap(alarm.nextFireDate()), future)
    }

    func testNotePreviewFallback() {
        XCTAssertEqual(NoteItem(title: "Leer").preview, "Keine weiteren Inhalte")
    }
}
