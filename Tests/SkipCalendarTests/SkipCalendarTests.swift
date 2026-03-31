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

