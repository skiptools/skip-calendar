// Copyright 2025–2026 Skip
// SPDX-License-Identifier: MPL-2.0

import Testing
import OSLog
import Foundation
@testable import SkipCalendar

let logger: Logger = Logger(subsystem: "SkipCalendar", category: "Tests")

@Suite struct SkipCalendarTests {

    @Test func testCalendarItemConstruction() throws {
        let cal = CalendarItem(id: "123", title: "Test Calendar", color: "#FF0000")
        #expect(cal.id == "123")
        #expect(cal.title == "Test Calendar")
        #expect(cal.color == "#FF0000")
        #expect(cal.isReadOnly == false)
        #expect(cal.isPrimary == false)
        #expect(cal.isVisible == true)
        #expect(cal.accessLevel == CalendarAccessLevel.owner)
    }

    @Test func testCalendarEventConstruction() throws {
        let start = Date()
        let end = Date(timeIntervalSinceNow: 3600)
        let event = CalendarEvent(
            calendarID: "1",
            title: "Test Event",
            location: "Room 42",
            notes: "Test notes",
            startDate: start,
            endDate: end,
            isAllDay: false
        )
        #expect(event.calendarID == "1")
        #expect(event.title == "Test Event")
        #expect(event.location == "Room 42")
        #expect(event.notes == "Test notes")
        #expect(event.isAllDay == false)
        #expect(event.alarms.isEmpty)
        #expect(event.recurrenceRules.isEmpty)
        #expect(event.attendees.isEmpty)
        #expect(event.id == nil)
        #expect(event.availability == EventAvailability.busy)
        #expect(event.status == EventStatus.none)
    }

    @Test func testCalendarAlarm() throws {
        let alarm1 = CalendarAlarm(relativeOffset: -15.0)
        #expect(alarm1.relativeOffset == -15.0)
        #expect(alarm1.absoluteDate == nil)

        let date = Date()
        let alarm2 = CalendarAlarm(absoluteDate: date)
        #expect(alarm2.absoluteDate != nil)
        #expect(alarm2.relativeOffset == 0.0)
    }

    @Test func testAttendeeConstruction() throws {
        let attendee = CalendarAttendee(
            name: "John Doe",
            email: "john@example.com",
            role: AttendeeRole.required,
            status: AttendeeStatus.accepted,
            type: AttendeeType.person,
            isCurrentUser: true
        )
        #expect(attendee.name == "John Doe")
        #expect(attendee.email == "john@example.com")
        #expect(attendee.role == AttendeeRole.required)
        #expect(attendee.status == AttendeeStatus.accepted)
        #expect(attendee.type == AttendeeType.person)
        #expect(attendee.isCurrentUser == true)
    }

    @Test func testDayOfWeek() throws {
        let monday = DayOfWeek(dayOfTheWeek: 2)
        #expect(monday.dayOfTheWeek == 2)
        #expect(monday.weekNumber == 0)

        let secondFriday = DayOfWeek(dayOfTheWeek: 6, weekNumber: 2)
        #expect(secondFriday.dayOfTheWeek == 6)
        #expect(secondFriday.weekNumber == 2)
    }

    @Test func testRecurrenceRuleDaily() throws {
        let rule = RecurrenceRule(frequency: RecurrenceFrequency.daily, interval: 2)
        let rrule = rule.toRRule()
        #expect(rrule == "FREQ=DAILY;INTERVAL=2")

        let parsed = RecurrenceRule.fromRRule(rrule)
        #expect(parsed != nil)
        #expect(parsed?.frequency == RecurrenceFrequency.daily)
        #expect(parsed?.interval == 2)
    }

    @Test func testRecurrenceRuleWeekly() throws {
        let rule = RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            daysOfTheWeek: [DayOfWeek(dayOfTheWeek: 2), DayOfWeek(dayOfTheWeek: 4), DayOfWeek(dayOfTheWeek: 6)]
        )
        let rrule = rule.toRRule()
        #expect(rrule.contains("FREQ=WEEKLY"))
        #expect(rrule.contains("BYDAY=MO,WE,FR"))

        let parsed = RecurrenceRule.fromRRule(rrule)
        #expect(parsed != nil)
        #expect(parsed?.frequency == RecurrenceFrequency.weekly)
        #expect(parsed?.daysOfTheWeek.count == 3)
    }

    @Test func testRecurrenceRuleMonthly() throws {
        let rule = RecurrenceRule(
            frequency: RecurrenceFrequency.monthly,
            daysOfTheMonth: [15, -1]
        )
        let rrule = rule.toRRule()
        #expect(rrule.contains("FREQ=MONTHLY"))
        #expect(rrule.contains("BYMONTHDAY=15,-1"))
    }

    @Test func testRecurrenceRuleYearly() throws {
        let rule = RecurrenceRule(
            frequency: RecurrenceFrequency.yearly,
            daysOfTheMonth: [15],
            monthsOfTheYear: [3]
        )
        let rrule = rule.toRRule()
        #expect(rrule.contains("FREQ=YEARLY"))
        #expect(rrule.contains("BYMONTH=3"))
        #expect(rrule.contains("BYMONTHDAY=15"))
    }

    @Test func testRecurrenceRuleWithCount() throws {
        let rule = RecurrenceRule(frequency: RecurrenceFrequency.daily, occurrenceCount: 10)
        let rrule = rule.toRRule()
        #expect(rrule == "FREQ=DAILY;COUNT=10")

        let parsed = RecurrenceRule.fromRRule(rrule)
        #expect(parsed?.occurrenceCount == 10)
    }

    @Test func testRecurrenceRuleWithEndDate() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let endDate = formatter.date(from: "20251231T235959Z")!

        let rule = RecurrenceRule(frequency: RecurrenceFrequency.weekly, endDate: endDate)
        let rrule = rule.toRRule()
        #expect(rrule.contains("FREQ=WEEKLY"))
        #expect(rrule.contains("UNTIL=20251231T235959Z"))

        let parsed = RecurrenceRule.fromRRule(rrule)
        #expect(parsed?.endDate != nil)
    }

    @Test func testRRuleParsingWithWeekNumber() throws {
        let parsed = RecurrenceRule.fromRRule("FREQ=MONTHLY;INTERVAL=2;BYDAY=2FR;COUNT=5")
        #expect(parsed != nil)
        #expect(parsed?.frequency == RecurrenceFrequency.monthly)
        #expect(parsed?.interval == 2)
        #expect(parsed?.occurrenceCount == 5)
        #expect(parsed?.daysOfTheWeek.count == 1)
        if let dow = parsed?.daysOfTheWeek.first {
            #expect(dow.dayOfTheWeek == 6)
            #expect(dow.weekNumber == 2)
        }
    }

    @Test func testRRuleRoundTrip() throws {
        let original = RecurrenceRule(
            frequency: RecurrenceFrequency.monthly,
            interval: 3,
            occurrenceCount: 12,
            daysOfTheWeek: [DayOfWeek(dayOfTheWeek: 2, weekNumber: -1)],
            daysOfTheMonth: [1, 15],
            monthsOfTheYear: [6, 12]
        )
        let rrule = original.toRRule()
        let parsed = RecurrenceRule.fromRRule(rrule)

        #expect(parsed != nil)
        #expect(parsed?.frequency == RecurrenceFrequency.monthly)
        #expect(parsed?.interval == 3)
        #expect(parsed?.occurrenceCount == 12)
        #expect(parsed?.daysOfTheWeek.count == 1)
        #expect(parsed?.daysOfTheMonth.count == 2)
        #expect(parsed?.monthsOfTheYear.count == 2)
    }

    @Test func testEventEditorOptions() throws {
        let options = EventEditorOptions(
            defaultTitle: "Meeting",
            defaultAllDay: false
        )
        #expect(options.defaultTitle == "Meeting")
        #expect(options.defaultAllDay == false)
        #expect(options.event == nil)
    }

    @Test func testCalendarSource() throws {
        let source = CalendarSource(id: "src1", name: "Local", type: "local")
        #expect(source.id == "src1")
        #expect(source.name == "Local")
        #expect(source.type == "local")
    }
}

// MARK: - Integration Tests (real calendar database)

/// Returns true only when running on a real Android device or emulator.
///
/// These integration tests are disabled on all Apple platforms because the
/// XCTest host process cannot communicate with the calendar/EventKit daemon
/// — even on the iOS simulator the process lacks the required entitlements
/// and every EKEventStore call fails with a communication error.
/// On macOS the test process similarly lacks calendar entitlements.
///
/// On Android the tests are disabled under Robolectric (no real
/// ContentProvider) but run on a connected emulator or device when
/// ANDROID_SERIAL is set.
private func isLiveDevice() -> Bool {
    #if SKIP
    return android.os.Build.FINGERPRINT != nil && "robolectric" != android.os.Build.FINGERPRINT
    #else
    return false
    #endif
}

/// Helper that creates a test calendar, runs `body` with its ID, then
/// cleans up the calendar (and all its events) afterward.
private func withTestCalendar(title: String = "SkipCalTest", body: (String) throws -> Void) throws {
    let manager = CalendarManager.shared
    let calID = try manager.createCalendar(title: title, color: "#0099FF")
    do {
        try body(calID)
        try manager.deleteCalendar(id: calID)
    } catch {
        try? manager.deleteCalendar(id: calID)
        throw error
    }
}

@Suite struct CalendarIntegrationTests {

    // SKIP INSERT:
    // @get:org.junit.Rule
    // val grantPermissionRule: androidx.test.rule.GrantPermissionRule = androidx.test.rule.GrantPermissionRule.grant(android.Manifest.permission.READ_CALENDAR, android.Manifest.permission.WRITE_CALENDAR)

    // MARK: - Calendars

    @Test func testGetCalendars() throws {
        guard isLiveDevice() else { return }

        let calendars = try CalendarManager.shared.getCalendars()
        // The emulator should have at least one calendar; just verify
        // the call succeeds and returns a list.
        #expect(calendars.count >= 0)
    }

    @Test func testCreateAndDeleteCalendar() throws {
        guard isLiveDevice() else { return }

        let manager = CalendarManager.shared
        let calID = try manager.createCalendar(title: "SkipCalInteg", color: "#FF5500")

        let calendars = try manager.getCalendars()
        let found = calendars.first { $0.id == calID }
        #expect(found != nil)
        #expect(found?.title == "SkipCalInteg")

        try manager.deleteCalendar(id: calID)
    }

    // MARK: - Events: Create & Fetch

    @Test func testCreateAndFetchEvent() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSinceNow: 86400 + 3600)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest Event",
                location: "Test Room",
                notes: "Integration test event",
                startDate: start,
                endDate: end
            )

            let eventID = try CalendarManager.shared.createEvent(event)

            let fetched = try CalendarManager.shared.getEvent(id: eventID)
            #expect(fetched != nil)
            #expect(fetched?.title == "SkipTest Event")
            #expect(fetched?.location == "Test Room")
            #expect(fetched?.notes == "Integration test event")

            try CalendarManager.shared.deleteEvent(id: eventID)
        }
    }

    @Test func testCreateAllDayEvent() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSinceNow: 86400 * 2)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest All Day",
                startDate: start,
                endDate: end,
                isAllDay: true
            )

            let eventID = try CalendarManager.shared.createEvent(event)

            let fetched = try CalendarManager.shared.getEvent(id: eventID)
            #expect(fetched != nil)
            #expect(fetched?.title == "SkipTest All Day")
            #expect(fetched?.isAllDay == true)

            try CalendarManager.shared.deleteEvent(id: eventID)
        }
    }

    /// An all-day event must round-trip to the same local calendar day. Android stores
    /// all-day events at midnight UTC; without normalization the day shifts for devices
    /// in non-UTC time zones. This asserts the day is preserved regardless of zone.
    @Test func testAllDayEventPreservesLocalDay() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSinceNow: 86400 * 2)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest AllDayTZ",
                startDate: start,
                endDate: end,
                isAllDay: true
            )
            let eventID = try manager.createEvent(event)

            let fetched = try manager.getEvent(id: eventID)
            #expect(fetched != nil)
            #expect(fetched?.isAllDay == true)

            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone.current
            if let fetchedStart = fetched?.startDate {
                let inComps = cal.dateComponents([.year, .month, .day], from: start)
                let outComps = cal.dateComponents([.year, .month, .day], from: fetchedStart)
                #expect(inComps.year == outComps.year)
                #expect(inComps.month == outComps.month)
                #expect(inComps.day == outComps.day)
            }

            try manager.deleteEvent(id: eventID)
        }
    }

    @Test func testCreateEventWithAlarm() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSinceNow: 86400 + 3600)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest Alarm",
                startDate: start,
                endDate: end,
                alarms: [CalendarAlarm(relativeOffset: -15.0)]
            )

            let eventID = try CalendarManager.shared.createEvent(event)

            let fetched = try CalendarManager.shared.getEvent(id: eventID)
            #expect(fetched != nil)
            #expect(fetched?.alarms.count == 1)
            #expect(fetched?.alarms.first?.relativeOffset == -15.0)

            try CalendarManager.shared.deleteEvent(id: eventID)
        }
    }

    // MARK: - Events: Query by date range

    @Test func testGetEventsInRange() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            let tomorrow = Date(timeIntervalSinceNow: 86400)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest Range",
                startDate: tomorrow,
                endDate: Date(timeIntervalSince1970: tomorrow.timeIntervalSince1970 + 3600)
            )
            let eventID = try manager.createEvent(event)

            // Query a range that includes the event
            let rangeStart = Date(timeIntervalSinceNow: 0)
            let rangeEnd = Date(timeIntervalSinceNow: 86400 * 3)
            let events = try manager.getEvents(calendarIDs: [calID], startDate: rangeStart, endDate: rangeEnd)
            let found = events.first { $0.title == "SkipTest Range" }
            #expect(found != nil)

            try manager.deleteEvent(id: eventID)
        }
    }

    @Test func testGetEventsOutOfRange() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            let nextWeek = Date(timeIntervalSinceNow: 86400 * 7)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest OutOfRange",
                startDate: nextWeek,
                endDate: Date(timeIntervalSince1970: nextWeek.timeIntervalSince1970 + 3600)
            )
            let eventID = try manager.createEvent(event)

            // Query a range that does NOT include the event
            let rangeStart = Date(timeIntervalSinceNow: 0)
            let rangeEnd = Date(timeIntervalSinceNow: 86400 * 2)
            let events = try manager.getEvents(calendarIDs: [calID], startDate: rangeStart, endDate: rangeEnd)
            let found = events.first { $0.title == "SkipTest OutOfRange" }
            #expect(found == nil)

            try manager.deleteEvent(id: eventID)
        }
    }

    // MARK: - Update

    @Test func testUpdateEvent() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSinceNow: 86400 + 3600)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest Before",
                startDate: start,
                endDate: end
            )
            let eventID = try manager.createEvent(event)

            let toUpdate = CalendarEvent(
                id: eventID,
                calendarID: calID,
                title: "SkipTest After",
                location: "Updated Room",
                notes: "Updated notes",
                startDate: start,
                endDate: end
            )
            try manager.updateEvent(toUpdate)

            let fetched = try manager.getEvent(id: eventID)
            #expect(fetched != nil)
            #expect(fetched?.title == "SkipTest After")
            #expect(fetched?.location == "Updated Room")
            #expect(fetched?.notes == "Updated notes")

            try manager.deleteEvent(id: eventID)
        }
    }

    // MARK: - Delete

    @Test func testDeleteEvent() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSinceNow: 86400 + 3600)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest Delete",
                startDate: start,
                endDate: end
            )
            let eventID = try manager.createEvent(event)

            // Verify it exists
            let before = try manager.getEvent(id: eventID)
            #expect(before != nil)

            // Delete it
            try manager.deleteEvent(id: eventID)

            // Verify it's gone
            let after = try manager.getEvent(id: eventID)
            #expect(after == nil)
        }
    }

    // MARK: - Multiple events

    @Test func testMultipleEvents() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            var eventIDs: [String] = []
            for i in 0..<3 {
                let start = Date(timeIntervalSinceNow: 86400 + Double(i) * 3600)
                let end = Date(timeIntervalSinceNow: 86400 + Double(i) * 3600 + 1800)
                let event = CalendarEvent(
                    calendarID: calID,
                    title: "SkipTest Multi \(i)",
                    startDate: start,
                    endDate: end
                )
                let id = try manager.createEvent(event)
                eventIDs.append(id)
            }

            let rangeStart = Date(timeIntervalSinceNow: 0)
            let rangeEnd = Date(timeIntervalSinceNow: 86400 * 3)
            let events = try manager.getEvents(calendarIDs: [calID], startDate: rangeStart, endDate: rangeEnd)
            let skipEvents = events.filter { $0.title.hasPrefix("SkipTest Multi") }
            #expect(skipEvents.count == 3)

            for id in eventIDs {
                try manager.deleteEvent(id: id)
            }
        }
    }

    // MARK: - Recurrence

    @Test func testEventWithRecurrence() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSinceNow: 86400 + 3600)
            let rule = RecurrenceRule(frequency: .weekly, interval: 1, occurrenceCount: 5)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest Recurring",
                startDate: start,
                endDate: end,
                recurrenceRules: [rule]
            )

            let eventID = try manager.createEvent(event)

            let fetched = try manager.getEvent(id: eventID)
            #expect(fetched != nil)
            #expect(fetched?.title == "SkipTest Recurring")
            #expect(fetched?.recurrenceRules.count == 1)
            #expect(fetched?.recurrenceRules.first?.frequency == .weekly)

            try manager.deleteEvent(id: eventID, span: .futureEvents)
        }
    }

    /// A recurring series must appear in a window that starts *after* its first
    /// occurrence. The previous Events-table query filtered on the master DTSTART,
    /// so a later weekly occurrence was silently dropped; querying the Instances
    /// table expands the series, matching iOS `predicateForEvents`.
    @Test func testRecurringEventAppearsInLaterWindow() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSince1970: start.timeIntervalSince1970 + 3600)
            let rule = RecurrenceRule(frequency: .weekly, interval: 1, occurrenceCount: 5)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest WeeklyExpand",
                startDate: start,
                endDate: end,
                recurrenceRules: [rule]
            )
            let eventID = try manager.createEvent(event)

            // Window begins five days out — past the first occurrence (+1 day) but
            // covering the second weekly occurrence (~+8 days).
            let rangeStart = Date(timeIntervalSinceNow: 86400 * 5)
            let rangeEnd = Date(timeIntervalSinceNow: 86400 * 12)
            let events = try manager.getEvents(calendarIDs: [calID], startDate: rangeStart, endDate: rangeEnd)
            let found = events.filter { $0.title == "SkipTest WeeklyExpand" }
            #expect(found.count >= 1)

            try manager.deleteEvent(id: eventID, span: .futureEvents)
        }
    }

    /// A recurring series must expand to one event per occurrence within the window.
    /// The Events-table query returned only the single master row.
    @Test func testRecurringEventExpandsToMultipleOccurrences() throws {
        guard isLiveDevice() else { return }

        try withTestCalendar { calID in
            let manager = CalendarManager.shared
            let start = Date(timeIntervalSinceNow: 86400)
            let end = Date(timeIntervalSince1970: start.timeIntervalSince1970 + 3600)
            let rule = RecurrenceRule(frequency: .weekly, interval: 1, occurrenceCount: 5)
            let event = CalendarEvent(
                calendarID: calID,
                title: "SkipTest WeeklyMulti",
                startDate: start,
                endDate: end,
                recurrenceRules: [rule]
            )
            let eventID = try manager.createEvent(event)

            // A 24-day window covers four of the five weekly occurrences.
            let rangeStart = Date(timeIntervalSinceNow: 0)
            let rangeEnd = Date(timeIntervalSinceNow: 86400 * 24)
            let events = try manager.getEvents(calendarIDs: [calID], startDate: rangeStart, endDate: rangeEnd)
            let occurrences = events.filter { $0.title == "SkipTest WeeklyMulti" }
            #expect(occurrences.count >= 3)

            try manager.deleteEvent(id: eventID, span: .futureEvents)
        }
    }

    // MARK: - Default calendar

    @Test func testGetDefaultCalendar() throws {
        guard isLiveDevice() else { return }

        // On Android emulators there may not be a default calendar,
        // so just verify the call doesn't throw.
        let _ = try CalendarManager.shared.getDefaultCalendar()
    }
}

