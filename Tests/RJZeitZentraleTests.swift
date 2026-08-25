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

    func testCustomDailyIntervalAndOccurrenceLimit() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 8,
            day: 25,
            hour: 9
        )))
        let rule = RJRecurrenceRule(
            frequency: .daily,
            interval: 2,
            occurrenceLimit: 3
        )
        let dates = rule.upcomingDates(startingAt: start, limit: 10, calendar: calendar)

        XCTAssertEqual(dates.count, 3)
        XCTAssertEqual(calendar.component(.day, from: dates[0]), 25)
        XCTAssertEqual(calendar.component(.day, from: dates[1]), 27)
        XCTAssertEqual(calendar.component(.day, from: dates[2]), 29)
    }

    func testCustomWeeklyWeekdays() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25,
            hour: 8
        )))
        let rule = RJRecurrenceRule(
            frequency: .weekly,
            weekdays: [.tuesday, .thursday],
            occurrenceLimit: 4
        )
        let dates = rule.upcomingDates(startingAt: start, limit: 10, calendar: calendar)

        XCTAssertEqual(dates.count, 4)
        XCTAssertEqual(dates.map { calendar.component(.weekday, from: $0) }, [3, 5, 3, 5])
    }

    func testRecurrenceEndDateIsRespected() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 9)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 27, hour: 23)))
        let rule = RJRecurrenceRule(frequency: .daily, endDate: end)
        XCTAssertEqual(rule.upcomingDates(startingAt: start, limit: 20, calendar: calendar).count, 3)
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

    func testLegacyReminderJSONMigratesWithSafeDefaults() throws {
        let data = try XCTUnwrap("""
        {"title":"Alte Erinnerung","recurrence":"weekly","notificationEnabled":true}
        """.data(using: .utf8))
        let reminder = try JSONDecoder().decode(ReminderItem.self, from: data)

        XCTAssertEqual(reminder.title, "Alte Erinnerung")
        XCTAssertEqual(reminder.recurrence, .weekly)
        XCTAssertEqual(reminder.notificationLeadTimes, [0])
        XCTAssertEqual(reminder.snoozeMinutes, 10)
        XCTAssertEqual(reminder.listName, "Allgemein")
        XCTAssertNil(reminder.locationTrigger)
    }

    func testLegacyNoteJSONMigratesWithoutMediaLoss() throws {
        let data = try XCTUnwrap("""
        {"title":"Alte Notiz","body":"Inhalt","pinned":true,"color":"purple"}
        """.data(using: .utf8))
        let note = try JSONDecoder().decode(NoteItem.self, from: data)

        XCTAssertTrue(note.pinned)
        XCTAssertEqual(note.color, .purple)
        XCTAssertTrue(note.attachments.isEmpty)
        XCTAssertTrue(note.recordings.isEmpty)
        XCTAssertFalse(note.archived)
        XCTAssertFalse(note.isTrashed)
    }

    func testLocationReminderRoundTrip() throws {
        let original = ReminderItem(
            title: "Beim Büro erinnern",
            locationTrigger: ReminderLocationTrigger(
                name: "Büro",
                address: "Musterstraße 1",
                latitude: 52.52,
                longitude: 13.405,
                radius: 200,
                event: .enter,
                repeats: true
            ),
            listName: "Arbeit",
            tags: ["#Wichtig"]
        )
        let decoded = try JSONDecoder().decode(
            ReminderItem.self,
            from: JSONEncoder().encode(original)
        )

        XCTAssertEqual(decoded.locationTrigger?.name, "Büro")
        XCTAssertEqual(decoded.locationTrigger?.radius, 200)
        XCTAssertEqual(decoded.listName, "Arbeit")
    }

    func testTagNormalizationRemovesDuplicates() {
        let note = NoteItem(title: "Tags", tags: ["#Idee", "idee", " Neue Idee "])
        XCTAssertEqual(note.normalizedTags, ["idee", "neue-idee"])
    }

    func testLegacyAlarmGetsPreAlertDefault() throws {
        let data = try XCTUnwrap("""
        {"title":"Alt","fireDate":0,"weekdays":[],"enabled":true}
        """.data(using: .utf8))
        let alarm = try JSONDecoder().decode(AlarmRecord.self, from: data)
        XCTAssertEqual(alarm.preAlertMinutes, 0)
        XCTAssertEqual(alarm.snoozeMinutes, 9)
    }
}
