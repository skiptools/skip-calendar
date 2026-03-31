// Copyright 2025–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import Foundation

// MARK: - Enums

/// The type of calendar entity
public enum CalendarEntityType : String {
    case event
    case reminder
}

/// Event availability status
public enum EventAvailability : String {
    case busy
    case free
    case tentative
    case unavailable
}

/// Event confirmation status
public enum EventStatus : String {
    case none
    case confirmed
    case tentative
    case canceled
}

/// Role of an attendee in an event
public enum AttendeeRole : String {
    case unknown
    case required
    case optional
    case chair
    case nonParticipant
    case organizer
}

/// Attendance response status
public enum AttendeeStatus : String {
    case unknown
    case pending
    case accepted
    case declined
    case tentative
    case delegated
    case completed
    case inProcess
}

/// Type of attendee
public enum AttendeeType : String {
    case unknown
    case person
    case room
    case group
    case resource
}

/// Frequency for recurrence rules
public enum RecurrenceFrequency : String {
    case daily
    case weekly
    case monthly
    case yearly
}

/// Span for event modifications (this event only or this and future events)
public enum EventSpan {
    case thisEvent
    case futureEvents
}

/// Calendar access level
public enum CalendarAccessLevel : String {
    case none
    case read
    case respond
    case freebusy
    case contributor
    case editor
    case owner
    case root
}

/// Result of an event editor interaction
public enum EventEditorResult : String {
    case saved
    case deleted
    case canceled
    case unknown
}

/// Errors from calendar operations
public enum CalendarError : Error {
    case permissionDenied
    case calendarNotFound
    case eventNotFound
    case saveFailed(String)
    case deleteFailed(String)
    case invalidData(String)
}

// MARK: - Data Types

/// Represents a calendar source or account
public struct CalendarSource {
    public let id: String
    public let name: String
    public let type: String

    public init(id: String, name: String, type: String) {
        self.id = id
        self.name = name
        self.type = type
    }
}

/// Represents a calendar on the device
public final class CalendarItem {
    public let id: String
    public var title: String
    public var color: String?
    public var isReadOnly: Bool
    public var source: CalendarSource?
    public var isPrimary: Bool
    public var accountName: String?
    public var ownerAccount: String?
    public var timeZone: String?
    public var accessLevel: CalendarAccessLevel
    public var isVisible: Bool

    public init(
        id: String,
        title: String,
        color: String? = nil,
        isReadOnly: Bool = false,
        source: CalendarSource? = nil,
        isPrimary: Bool = false,
        accountName: String? = nil,
        ownerAccount: String? = nil,
        timeZone: String? = nil,
        accessLevel: CalendarAccessLevel = .owner,
        isVisible: Bool = true
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.isReadOnly = isReadOnly
        self.source = source
        self.isPrimary = isPrimary
        self.accountName = accountName
        self.ownerAccount = ownerAccount
        self.timeZone = timeZone
        self.accessLevel = accessLevel
        self.isVisible = isVisible
    }
}

/// Represents a calendar event
public final class CalendarEvent {
    public var id: String?
    public var calendarID: String
    public var title: String
    public var location: String?
    public var notes: String?
    public var url: String?
    public var startDate: Date
    public var endDate: Date
    public var timeZone: String?
    public var isAllDay: Bool
    public var availability: EventAvailability
    public var status: EventStatus
    public var alarms: [CalendarAlarm]
    public var recurrenceRules: [RecurrenceRule]
    public var attendees: [CalendarAttendee]
    public var organizerEmail: String?
    public var creationDate: Date?
    public var lastModifiedDate: Date?

    public init(
        id: String? = nil,
        calendarID: String,
        title: String,
        location: String? = nil,
        notes: String? = nil,
        url: String? = nil,
        startDate: Date,
        endDate: Date,
        timeZone: String? = nil,
        isAllDay: Bool = false,
        availability: EventAvailability = .busy,
        status: EventStatus = .none,
        alarms: [CalendarAlarm] = [],
        recurrenceRules: [RecurrenceRule] = [],
        attendees: [CalendarAttendee] = [],
        organizerEmail: String? = nil,
        creationDate: Date? = nil,
        lastModifiedDate: Date? = nil
    ) {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.location = location
        self.notes = notes
        self.url = url
        self.startDate = startDate
        self.endDate = endDate
        self.timeZone = timeZone
        self.isAllDay = isAllDay
        self.availability = availability
        self.status = status
        self.alarms = alarms
        self.recurrenceRules = recurrenceRules
        self.attendees = attendees
        self.organizerEmail = organizerEmail
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
    }
}

/// Represents an event attendee
public struct CalendarAttendee {
    public let id: String?
    public let name: String?
    public let email: String?
    public let role: AttendeeRole
    public let status: AttendeeStatus
    public let type: AttendeeType
    public let isCurrentUser: Bool

    public init(
        id: String? = nil,
        name: String? = nil,
        email: String? = nil,
        role: AttendeeRole = .unknown,
        status: AttendeeStatus = .unknown,
        type: AttendeeType = .unknown,
        isCurrentUser: Bool = false
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.status = status
        self.type = type
        self.isCurrentUser = isCurrentUser
    }
}

/// Represents an alarm or reminder for an event
public struct CalendarAlarm {
    /// Minutes relative to the event start (negative means before, e.g. -15 = 15 minutes before)
    public var relativeOffset: Double
    /// Absolute date for the alarm (iOS only; overrides relativeOffset when set)
    public var absoluteDate: Date?

    /// Create an alarm with a relative offset in minutes (negative = before event)
    public init(relativeOffset: Double = -15.0) {
        self.relativeOffset = relativeOffset
        self.absoluteDate = nil
    }

    /// Create an alarm at an absolute date (iOS only)
    public init(absoluteDate: Date) {
        self.relativeOffset = 0.0
        self.absoluteDate = absoluteDate
    }
}

/// Day of the week with optional week number for recurrence rules
public struct DayOfWeek {
    /// Day of the week: 1=Sunday, 2=Monday, ..., 7=Saturday
    public let dayOfTheWeek: Int
    /// Week number for monthly recurrences (-5 to 5, 0 means no specific week)
    public let weekNumber: Int

    public init(dayOfTheWeek: Int, weekNumber: Int = 0) {
        self.dayOfTheWeek = dayOfTheWeek
        self.weekNumber = weekNumber
    }
}

/// Recurrence rule for repeating events (follows iCal RFC 5545)
public final class RecurrenceRule {
    public var frequency: RecurrenceFrequency
    public var interval: Int
    public var endDate: Date?
    public var occurrenceCount: Int
    /// Days of the week (iOS + Android RRULE BYDAY)
    public var daysOfTheWeek: [DayOfWeek]
    /// Days of the month, 1-31 or negative from end (iOS + Android RRULE BYMONTHDAY)
    public var daysOfTheMonth: [Int]
    /// Months of the year, 1-12 (iOS + Android RRULE BYMONTH)
    public var monthsOfTheYear: [Int]
    /// Weeks of the year, 1-53 or negative from end (iOS only)
    public var weeksOfTheYear: [Int]
    /// Days of the year, 1-366 or negative from end (iOS only)
    public var daysOfTheYear: [Int]
    /// Filter positions (iOS only)
    public var setPositions: [Int]

    public init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        endDate: Date? = nil,
        occurrenceCount: Int = 0,
        daysOfTheWeek: [DayOfWeek] = [],
        daysOfTheMonth: [Int] = [],
        monthsOfTheYear: [Int] = [],
        weeksOfTheYear: [Int] = [],
        daysOfTheYear: [Int] = [],
        setPositions: [Int] = []
    ) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.occurrenceCount = occurrenceCount
        self.daysOfTheWeek = daysOfTheWeek
        self.daysOfTheMonth = daysOfTheMonth
        self.monthsOfTheYear = monthsOfTheYear
        self.weeksOfTheYear = weeksOfTheYear
        self.daysOfTheYear = daysOfTheYear
        self.setPositions = setPositions
    }
}

// MARK: - RRULE Conversion

extension RecurrenceRule {
    private static let dayNames = ["", "SU", "MO", "TU", "WE", "TH", "FR", "SA"]
    private static let dayMap: [String: Int] = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]

    /// Convert this recurrence rule to an iCal RRULE string
    public func toRRule() -> String {
        var parts: [String] = []

        switch frequency {
        case .daily: parts.append("FREQ=DAILY")
        case .weekly: parts.append("FREQ=WEEKLY")
        case .monthly: parts.append("FREQ=MONTHLY")
        case .yearly: parts.append("FREQ=YEARLY")
        }

        if interval > 1 {
            parts.append("INTERVAL=\(interval)")
        }

        if occurrenceCount > 0 {
            parts.append("COUNT=\(occurrenceCount)")
        }

        if let endDate = endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(identifier: "UTC")
            parts.append("UNTIL=" + formatter.string(from: endDate))
        }

        if !daysOfTheWeek.isEmpty {
            let dayStrings: [String] = daysOfTheWeek.map { dow in
                let dayAbbr = (dow.dayOfTheWeek >= 1 && dow.dayOfTheWeek <= 7) ? RecurrenceRule.dayNames[dow.dayOfTheWeek] : "MO"
                if dow.weekNumber != 0 {
                    return "\(dow.weekNumber)" + dayAbbr
                }
                return dayAbbr
            }
            parts.append("BYDAY=" + dayStrings.joined(separator: ","))
        }

        if !daysOfTheMonth.isEmpty {
            parts.append("BYMONTHDAY=" + daysOfTheMonth.map({ "\($0)" }).joined(separator: ","))
        }

        if !monthsOfTheYear.isEmpty {
            parts.append("BYMONTH=" + monthsOfTheYear.map({ "\($0)" }).joined(separator: ","))
        }

        if !weeksOfTheYear.isEmpty {
            parts.append("BYWEEKNO=" + weeksOfTheYear.map({ "\($0)" }).joined(separator: ","))
        }

        if !daysOfTheYear.isEmpty {
            parts.append("BYYEARDAY=" + daysOfTheYear.map({ "\($0)" }).joined(separator: ","))
        }

        if !setPositions.isEmpty {
            parts.append("BYSETPOS=" + setPositions.map({ "\($0)" }).joined(separator: ","))
        }

        return parts.joined(separator: ";")
    }

    /// Parse an iCal RRULE string into a RecurrenceRule
    public static func fromRRule(_ rrule: String) -> RecurrenceRule? {
        var frequency: RecurrenceFrequency = .daily
        var interval = 1
        var endDate: Date? = nil
        var occurrenceCount = 0
        var daysOfWeek: [DayOfWeek] = []
        var daysOfMonth: [Int] = []
        var months: [Int] = []
        var weeksOfYear: [Int] = []
        var daysOfYear: [Int] = []
        var positions: [Int] = []

        let components = rrule.components(separatedBy: ";")
        for component in components {
            let keyValue = component.components(separatedBy: "=")
            if keyValue.count != 2 { continue }
            let key = keyValue[0]
            let value = keyValue[1]

            switch key {
            case "FREQ":
                switch value {
                case "DAILY": frequency = .daily
                case "WEEKLY": frequency = .weekly
                case "MONTHLY": frequency = .monthly
                case "YEARLY": frequency = .yearly
                default: break
                }
            case "INTERVAL":
                interval = Int(value) ?? 1
            case "COUNT":
                occurrenceCount = Int(value) ?? 0
            case "UNTIL":
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone(identifier: "UTC")
                formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                endDate = formatter.date(from: value)
                if endDate == nil {
                    formatter.dateFormat = "yyyyMMdd"
                    endDate = formatter.date(from: value)
                }
            case "BYDAY":
                let days = value.components(separatedBy: ",")
                for day in days {
                    let trimmed = day.trimmingCharacters(in: .whitespaces)
                    if trimmed.count == 2 {
                        if let dayNum = dayMap[trimmed] {
                            daysOfWeek.append(DayOfWeek(dayOfTheWeek: dayNum))
                        }
                    } else if trimmed.count >= 3 {
                        let dayAbbr = String(trimmed.suffix(2))
                        let weekStr = String(trimmed.dropLast(2))
                        if let dayNum = dayMap[dayAbbr], let weekNum = Int(weekStr) {
                            daysOfWeek.append(DayOfWeek(dayOfTheWeek: dayNum, weekNumber: weekNum))
                        }
                    }
                }
            case "BYMONTHDAY":
                daysOfMonth = value.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            case "BYMONTH":
                months = value.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            case "BYWEEKNO":
                weeksOfYear = value.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            case "BYYEARDAY":
                daysOfYear = value.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            case "BYSETPOS":
                positions = value.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            default:
                break
            }
        }

        return RecurrenceRule(
            frequency: frequency,
            interval: interval,
            endDate: endDate,
            occurrenceCount: occurrenceCount,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: daysOfMonth,
            monthsOfTheYear: months,
            weeksOfTheYear: weeksOfYear,
            daysOfTheYear: daysOfYear,
            setPositions: positions
        )
    }
}

/// Options for the event editor UI
public struct EventEditorOptions {
    public var event: CalendarEvent?
    public var defaultCalendarID: String?
    public var defaultTitle: String?
    public var defaultLocation: String?
    public var defaultNotes: String?
    public var defaultStartDate: Date?
    public var defaultEndDate: Date?
    public var defaultAllDay: Bool

    public init(
        event: CalendarEvent? = nil,
        defaultCalendarID: String? = nil,
        defaultTitle: String? = nil,
        defaultLocation: String? = nil,
        defaultNotes: String? = nil,
        defaultStartDate: Date? = nil,
        defaultEndDate: Date? = nil,
        defaultAllDay: Bool = false
    ) {
        self.event = event
        self.defaultCalendarID = defaultCalendarID
        self.defaultTitle = defaultTitle
        self.defaultLocation = defaultLocation
        self.defaultNotes = defaultNotes
        self.defaultStartDate = defaultStartDate
        self.defaultEndDate = defaultEndDate
        self.defaultAllDay = defaultAllDay
    }
}

#endif
