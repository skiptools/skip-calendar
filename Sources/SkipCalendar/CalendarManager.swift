// Copyright 2025–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import Foundation
import OSLog
import SkipKit

#if !SKIP
import EventKit
#else
import android.content.ContentResolver
import android.content.ContentValues
import android.content.ContentUris
import android.database.Cursor
import android.provider.CalendarContract
#endif

/// Main interface for calendar operations on both iOS and Android.
///
/// Use `CalendarManager.shared` to access the singleton instance.
/// Always request permissions before accessing calendar data.
public final class CalendarManager {
    /// Shared singleton instance
    public nonisolated(unsafe) static let shared = CalendarManager()

    #if !SKIP
    /// The underlying EventKit event store (iOS/macOS).
    /// Use this for advanced EventKit operations not covered by the cross-platform API.
    public let eventStore = EKEventStore()
    #endif

    private init() {
    }

    // MARK: - Permissions

    /// Query the current calendar permission status without prompting the user.
    public static func queryCalendarPermission() -> PermissionAuthorization {
        #if !SKIP
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined: return .unknown
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .fullAccess, .writeOnly: return .authorized
        @unknown default: return .unknown
        }
        #else
        return PermissionManager.queryPermission(.READ_CALENDAR)
        #endif
    }

    /// Request calendar read/write permission from the user.
    /// Returns `.authorized` if granted, `.denied` if rejected.
    /* SKIP @nobridge */ public static func requestCalendarPermission() async -> PermissionAuthorization {
        #if !SKIP
        let current = queryCalendarPermission()
        if current != .unknown { return current }
        let store = EKEventStore()
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                try await store.requestFullAccessToEvents()
            } else {
                try await store.requestAccess(to: .event)
            }
        } catch {
            logger.error("Failed to request calendar permission: \(error)")
        }
        return queryCalendarPermission()
        #else
        let readResult = await PermissionManager.requestPermission(.READ_CALENDAR)
        if readResult != .authorized { return readResult }
        return await PermissionManager.requestPermission(.WRITE_CALENDAR)
        #endif
    }

    /// Query the current reminder permission status (iOS only).
    /// On Android, calendar permission covers reminders, so this returns the calendar permission status.
    public static func queryReminderPermission() -> PermissionAuthorization {
        #if !SKIP
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .notDetermined: return .unknown
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized, .fullAccess, .writeOnly: return .authorized
        @unknown default: return .unknown
        }
        #else
        return PermissionManager.queryPermission(.READ_CALENDAR)
        #endif
    }

    /// Request reminder permission (iOS only).
    /// On Android, this requests calendar permission since it covers reminders.
    /* SKIP @nobridge */ public static func requestReminderPermission() async -> PermissionAuthorization {
        #if !SKIP
        let current = queryReminderPermission()
        if current != .unknown { return current }
        let store = EKEventStore()
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                try await store.requestFullAccessToReminders()
            } else {
                try await store.requestAccess(to: .reminder)
            }
        } catch {
            logger.error("Failed to request reminder permission: \(error)")
        }
        return queryReminderPermission()
        #else
        return await requestCalendarPermission()
        #endif
    }

    // MARK: - Calendars

    /// Get all calendars on the device.
    /// - Parameter entityType: `.event` for event calendars (default), `.reminder` for reminder calendars (iOS only)
    public func getCalendars(entityType: CalendarEntityType = .event) throws -> [CalendarItem] {
        #if !SKIP
        let ekEntityType: EKEntityType = entityType == .reminder ? .reminder : .event
        let calendars = eventStore.calendars(for: ekEntityType)
        return calendars.map { calendarItemFromEK($0) }
        #else
        return try getAndroidCalendars()
        #endif
    }

    /// Get the default calendar for new events.
    public func getDefaultCalendar() throws -> CalendarItem? {
        #if !SKIP
        if let cal = eventStore.defaultCalendarForNewEvents {
            return calendarItemFromEK(cal)
        }
        return nil
        #else
        return try getAndroidDefaultCalendar()
        #endif
    }

    /// Create a new local calendar.
    /// - Parameters:
    ///   - title: Display name for the calendar
    ///   - color: Hex color string (e.g. "#FF0000")
    /// - Returns: The ID of the newly created calendar
    public func createCalendar(title: String, color: String? = nil) throws -> String {
        #if !SKIP
        let newCal = EKCalendar(for: .event, eventStore: eventStore)
        newCal.title = title
        if let color = color {
            newCal.cgColor = colorFromHex(color)
        }
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCal.source = localSource
        } else if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            newCal.source = defaultSource
        }
        try eventStore.saveCalendar(newCal, commit: true)
        return newCal.calendarIdentifier
        #else
        return try createAndroidCalendar(title: title, color: color)
        #endif
    }

    /// Delete a calendar by its ID.
    public func deleteCalendar(id: String) throws {
        #if !SKIP
        guard let cal = eventStore.calendar(withIdentifier: id) else {
            throw CalendarError.calendarNotFound
        }
        try eventStore.removeCalendar(cal, commit: true)
        #else
        try deleteAndroidCalendar(id: id)
        #endif
    }

    // MARK: - Events

    /// Get events within a date range.
    /// - Parameters:
    ///   - calendarIDs: Optional array of calendar IDs to filter by. Pass nil for all calendars.
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    /// - Returns: Array of events within the date range
    public func getEvents(calendarIDs: [String]? = nil, startDate: Date, endDate: Date) throws -> [CalendarEvent] {
        #if !SKIP
        var calendars: [EKCalendar]? = nil
        if let ids = calendarIDs {
            calendars = ids.compactMap { eventStore.calendar(withIdentifier: $0) }
        }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)
        return ekEvents.map { eventFromEK($0) }
        #else
        return try getAndroidEvents(calendarIDs: calendarIDs, startDate: startDate, endDate: endDate)
        #endif
    }

    /// Get a single event by its ID.
    public func getEvent(id: String) throws -> CalendarEvent? {
        #if !SKIP
        guard let ekEvent = eventStore.event(withIdentifier: id) else { return nil }
        return eventFromEK(ekEvent)
        #else
        return try getAndroidEvent(id: id)
        #endif
    }

    /// Create a new event.
    /// - Parameter event: The event to create. The `id` property is ignored; a new ID is assigned.
    /// - Returns: The ID of the newly created event
    public func createEvent(_ event: CalendarEvent) throws -> String {
        #if !SKIP
        let ekEvent = EKEvent(eventStore: eventStore)
        applyEventToEK(event, ekEvent: ekEvent)
        try eventStore.save(ekEvent, span: .thisEvent)
        event.id = ekEvent.eventIdentifier
        return ekEvent.eventIdentifier
        #else
        let newID = try createAndroidEvent(event)
        event.id = newID
        return newID
        #endif
    }

    /// Update an existing event. The event must have a valid `id`.
    /// - Parameters:
    ///   - event: The event with updated properties
    ///   - span: Whether to update only this instance or all future instances of a recurring event
    public func updateEvent(_ event: CalendarEvent, span: EventSpan = .thisEvent) throws {
        #if !SKIP
        guard let eventID = event.id else {
            throw CalendarError.invalidData("Event ID is required for update")
        }
        guard let ekEvent = eventStore.event(withIdentifier: eventID) else {
            throw CalendarError.eventNotFound
        }
        applyEventToEK(event, ekEvent: ekEvent)
        let ekSpan: EKSpan = span == .futureEvents ? .futureEvents : .thisEvent
        try eventStore.save(ekEvent, span: ekSpan)
        #else
        try updateAndroidEvent(event)
        #endif
    }

    /// Delete an event by its ID.
    /// - Parameters:
    ///   - id: The event ID
    ///   - span: Whether to delete only this instance or all future instances of a recurring event
    public func deleteEvent(id: String, span: EventSpan = .thisEvent) throws {
        #if !SKIP
        guard let ekEvent = eventStore.event(withIdentifier: id) else {
            throw CalendarError.eventNotFound
        }
        let ekSpan: EKSpan = span == .futureEvents ? .futureEvents : .thisEvent
        try eventStore.remove(ekEvent, span: ekSpan)
        #else
        try deleteAndroidEvent(id: id)
        #endif
    }

    /// Get attendees for an event.
    /// On iOS, attendees are read-only (managed by the calendar service).
    /// On Android, attendees are read from the CalendarContract.Attendees table.
    public func getAttendees(eventID: String) throws -> [CalendarAttendee] {
        #if !SKIP
        guard let ekEvent = eventStore.event(withIdentifier: eventID) else {
            throw CalendarError.eventNotFound
        }
        return (ekEvent.attendees ?? []).map { attendeeFromEK($0) }
        #else
        return try getAndroidAttendees(eventID: eventID)
        #endif
    }

    // MARK: - iOS EventKit Helpers

    #if !SKIP
    private func calendarItemFromEK(_ cal: EKCalendar) -> CalendarItem {
        return CalendarItem(
            id: cal.calendarIdentifier,
            title: cal.title,
            color: hexFromCGColor(cal.cgColor),
            isReadOnly: !cal.allowsContentModifications,
            source: CalendarSource(
                id: cal.source.sourceIdentifier,
                name: cal.source.title,
                type: "\(cal.source.sourceType.rawValue)"
            ),
            isPrimary: cal.calendarIdentifier == eventStore.defaultCalendarForNewEvents?.calendarIdentifier,
            accessLevel: .owner,
            isVisible: true
        )
    }

    private func eventFromEK(_ ekEvent: EKEvent) -> CalendarEvent {
        let alarms: [CalendarAlarm] = (ekEvent.alarms ?? []).map { alarm in
            if let absDate = alarm.absoluteDate {
                return CalendarAlarm(absoluteDate: absDate)
            }
            return CalendarAlarm(relativeOffset: alarm.relativeOffset / 60.0)
        }

        let recurrenceRules: [RecurrenceRule] = (ekEvent.recurrenceRules ?? []).map { recurrenceRuleFromEK($0) }
        let attendees: [CalendarAttendee] = (ekEvent.attendees ?? []).map { attendeeFromEK($0) }

        let availability: EventAvailability
        switch ekEvent.availability {
        case .notSupported: availability = .busy
        case .busy: availability = .busy
        case .free: availability = .free
        case .tentative: availability = .tentative
        case .unavailable: availability = .unavailable
        @unknown default: availability = .busy
        }

        let status: EventStatus
        switch ekEvent.status {
        case .none: status = .none
        case .confirmed: status = .confirmed
        case .tentative: status = .tentative
        case .canceled: status = .canceled
        @unknown default: status = .none
        }

        return CalendarEvent(
            id: ekEvent.eventIdentifier,
            calendarID: ekEvent.calendar.calendarIdentifier,
            title: ekEvent.title ?? "",
            location: ekEvent.location,
            notes: ekEvent.notes,
            url: ekEvent.url?.absoluteString,
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            timeZone: ekEvent.timeZone?.identifier,
            isAllDay: ekEvent.isAllDay,
            availability: availability,
            status: status,
            alarms: alarms,
            recurrenceRules: recurrenceRules,
            attendees: attendees,
            organizerEmail: ekEvent.organizer?.url.absoluteString.replacingOccurrences(of: "mailto:", with: ""),
            creationDate: ekEvent.creationDate,
            lastModifiedDate: ekEvent.lastModifiedDate
        )
    }

    private func applyEventToEK(_ event: CalendarEvent, ekEvent: EKEvent) {
        if let cal = eventStore.calendar(withIdentifier: event.calendarID) {
            ekEvent.calendar = cal
        } else {
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
        }
        ekEvent.title = event.title
        ekEvent.location = event.location
        ekEvent.notes = event.notes
        ekEvent.startDate = event.startDate
        ekEvent.endDate = event.endDate
        ekEvent.isAllDay = event.isAllDay

        if let urlString = event.url, let eventURL = URL(string: urlString) {
            ekEvent.url = eventURL
        }
        if let tz = event.timeZone {
            ekEvent.timeZone = TimeZone(identifier: tz)
        }

        switch event.availability {
        case .busy: ekEvent.availability = .busy
        case .free: ekEvent.availability = .free
        case .tentative: ekEvent.availability = .tentative
        case .unavailable: ekEvent.availability = .unavailable
        }

        // Set alarms
        ekEvent.alarms = nil
        for alarm in event.alarms {
            if let absDate = alarm.absoluteDate {
                ekEvent.addAlarm(EKAlarm(absoluteDate: absDate))
            } else {
                ekEvent.addAlarm(EKAlarm(relativeOffset: alarm.relativeOffset * 60.0))
            }
        }

        // Set recurrence rules
        if let existingRules = ekEvent.recurrenceRules {
            for rule in existingRules {
                ekEvent.removeRecurrenceRule(rule)
            }
        }
        for rule in event.recurrenceRules {
            ekEvent.addRecurrenceRule(recurrenceRuleToEK(rule))
        }
    }

    private func recurrenceRuleFromEK(_ ekRule: EKRecurrenceRule) -> RecurrenceRule {
        let frequency: RecurrenceFrequency
        switch ekRule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: frequency = .daily
        }

        let daysOfWeek: [DayOfWeek] = (ekRule.daysOfTheWeek ?? []).map { dow in
            DayOfWeek(dayOfTheWeek: dow.dayOfTheWeek.rawValue, weekNumber: dow.weekNumber)
        }
        let daysOfMonth: [Int] = (ekRule.daysOfTheMonth ?? []).map { $0.intValue }
        let months: [Int] = (ekRule.monthsOfTheYear ?? []).map { $0.intValue }
        let weeksOfYear: [Int] = (ekRule.weeksOfTheYear ?? []).map { $0.intValue }
        let daysOfYear: [Int] = (ekRule.daysOfTheYear ?? []).map { $0.intValue }
        let positions: [Int] = (ekRule.setPositions ?? []).map { $0.intValue }

        var ruleEndDate: Date? = nil
        var count = 0
        if let recEnd = ekRule.recurrenceEnd {
            if let endD = recEnd.endDate {
                ruleEndDate = endD
            } else {
                count = recEnd.occurrenceCount
            }
        }

        return RecurrenceRule(
            frequency: frequency,
            interval: ekRule.interval,
            endDate: ruleEndDate,
            occurrenceCount: count,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: daysOfMonth,
            monthsOfTheYear: months,
            weeksOfTheYear: weeksOfYear,
            daysOfTheYear: daysOfYear,
            setPositions: positions
        )
    }

    private func recurrenceRuleToEK(_ rule: RecurrenceRule) -> EKRecurrenceRule {
        let ekFrequency: EKRecurrenceFrequency
        switch rule.frequency {
        case .daily: ekFrequency = .daily
        case .weekly: ekFrequency = .weekly
        case .monthly: ekFrequency = .monthly
        case .yearly: ekFrequency = .yearly
        }

        let daysOfWeek: [EKRecurrenceDayOfWeek]? = rule.daysOfTheWeek.isEmpty ? nil : rule.daysOfTheWeek.map { dow in
            EKRecurrenceDayOfWeek(EKWeekday(rawValue: dow.dayOfTheWeek)!, weekNumber: dow.weekNumber)
        }
        let daysOfMonth: [NSNumber]? = rule.daysOfTheMonth.isEmpty ? nil : rule.daysOfTheMonth.map { NSNumber(value: $0) }
        let months: [NSNumber]? = rule.monthsOfTheYear.isEmpty ? nil : rule.monthsOfTheYear.map { NSNumber(value: $0) }
        let weeksOfYear: [NSNumber]? = rule.weeksOfTheYear.isEmpty ? nil : rule.weeksOfTheYear.map { NSNumber(value: $0) }
        let daysOfYear: [NSNumber]? = rule.daysOfTheYear.isEmpty ? nil : rule.daysOfTheYear.map { NSNumber(value: $0) }
        let positions: [NSNumber]? = rule.setPositions.isEmpty ? nil : rule.setPositions.map { NSNumber(value: $0) }

        var recEnd: EKRecurrenceEnd? = nil
        if let endDate = rule.endDate {
            recEnd = EKRecurrenceEnd(end: endDate)
        } else if rule.occurrenceCount > 0 {
            recEnd = EKRecurrenceEnd(occurrenceCount: rule.occurrenceCount)
        }

        return EKRecurrenceRule(
            recurrenceWith: ekFrequency,
            interval: rule.interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: daysOfMonth,
            monthsOfTheYear: months,
            weeksOfTheYear: weeksOfYear,
            daysOfTheYear: daysOfYear,
            setPositions: positions,
            end: recEnd
        )
    }

    private func attendeeFromEK(_ participant: EKParticipant) -> CalendarAttendee {
        let role: AttendeeRole
        switch participant.participantRole {
        case .unknown: role = .unknown
        case .required: role = .required
        case .optional: role = .optional
        case .chair: role = .chair
        case .nonParticipant: role = .nonParticipant
        @unknown default: role = .unknown
        }

        let status: AttendeeStatus
        switch participant.participantStatus {
        case .unknown: status = .unknown
        case .pending: status = .pending
        case .accepted: status = .accepted
        case .declined: status = .declined
        case .tentative: status = .tentative
        case .delegated: status = .delegated
        case .completed: status = .completed
        case .inProcess: status = .inProcess
        @unknown default: status = .unknown
        }

        let atype: AttendeeType
        switch participant.participantType {
        case .unknown: atype = .unknown
        case .person: atype = .person
        case .room: atype = .room
        case .group: atype = .group
        case .resource: atype = .resource
        @unknown default: atype = .unknown
        }

        return CalendarAttendee(
            name: participant.name,
            email: participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: ""),
            role: role,
            status: status,
            type: atype,
            isCurrentUser: participant.isCurrentUser
        )
    }

    private func hexFromCGColor(_ cgColor: CGColor?) -> String? {
        guard let cgColor = cgColor,
              let components = cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func colorFromHex(_ hex: String) -> CGColor {
        var hexString = hex
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst())
        }
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    #endif

    // MARK: - Android CalendarContract Helpers

    #if SKIP
    private var contentResolver: android.content.ContentResolver {
        ProcessInfo.processInfo.androidContext.contentResolver
    }

    private func cursorString(_ cursor: android.database.Cursor, _ column: String) -> String? {
        let index = cursor.getColumnIndex(column)
        if index < 0 || cursor.isNull(index) { return nil }
        return cursor.getString(index)
    }

    private func cursorLong(_ cursor: android.database.Cursor, _ column: String) -> Int64 {
        let index = cursor.getColumnIndex(column)
        if index < 0 { return Int64(0) }
        return cursor.getLong(index)
    }

    private func cursorInt(_ cursor: android.database.Cursor, _ column: String) -> Int {
        let index = cursor.getColumnIndex(column)
        if index < 0 { return 0 }
        return cursor.getInt(index)
    }

    // MARK: Android Calendar Operations

    private func getAndroidCalendars() throws -> [CalendarItem] {
        let projection = [
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.CALENDAR_COLOR,
            CalendarContract.Calendars.IS_PRIMARY,
            CalendarContract.Calendars.OWNER_ACCOUNT,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            CalendarContract.Calendars.CALENDAR_TIME_ZONE,
            CalendarContract.Calendars.VISIBLE,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE
        ]

        guard let cursor = contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection.toList().toTypedArray(),
            nil, nil, nil
        ) else {
            return []
        }

        defer { cursor.close() }
        var results: [CalendarItem] = []

        while cursor.moveToNext() {
            let id = "\(cursorLong(cursor, CalendarContract.Calendars._ID))"
            let title = cursorString(cursor, CalendarContract.Calendars.CALENDAR_DISPLAY_NAME) ?? ""
            let colorInt = cursorInt(cursor, CalendarContract.Calendars.CALENDAR_COLOR)
            let isPrimary = cursorInt(cursor, CalendarContract.Calendars.IS_PRIMARY) == 1
            let ownerAccount = cursorString(cursor, CalendarContract.Calendars.OWNER_ACCOUNT)
            let accessLevelInt = cursorInt(cursor, CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL)
            let timeZone = cursorString(cursor, CalendarContract.Calendars.CALENDAR_TIME_ZONE)
            let visible = cursorInt(cursor, CalendarContract.Calendars.VISIBLE) == 1
            let accountName = cursorString(cursor, CalendarContract.Calendars.ACCOUNT_NAME)
            let accountType = cursorString(cursor, CalendarContract.Calendars.ACCOUNT_TYPE)

            let isReadOnly = accessLevelInt < CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR

            results.append(CalendarItem(
                id: id,
                title: title,
                color: androidColorToHex(colorInt),
                isReadOnly: isReadOnly,
                source: CalendarSource(
                    id: accountName ?? "",
                    name: accountName ?? "",
                    type: accountType ?? ""
                ),
                isPrimary: isPrimary,
                accountName: accountName,
                ownerAccount: ownerAccount,
                timeZone: timeZone,
                accessLevel: androidAccessLevel(accessLevelInt),
                isVisible: visible
            ))
        }

        return results
    }

    private func getAndroidDefaultCalendar() throws -> CalendarItem? {
        let calendars = try getAndroidCalendars()
        if let primary = calendars.first(where: { $0.isPrimary && !$0.isReadOnly }) {
            return primary
        }
        return calendars.first(where: { !$0.isReadOnly })
    }

    private func createAndroidCalendar(title: String, color: String?) throws -> String {
        let values = ContentValues()
        values.put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, title)
        values.put(CalendarContract.Calendars.ACCOUNT_NAME, "SkipCalendar")
        values.put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
        values.put(CalendarContract.Calendars.OWNER_ACCOUNT, "SkipCalendar")
        values.put(CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL, CalendarContract.Calendars.CAL_ACCESS_OWNER)
        values.put(CalendarContract.Calendars.VISIBLE, 1)
        values.put(CalendarContract.Calendars.SYNC_EVENTS, 1)
        values.put(CalendarContract.Calendars.CALENDAR_TIME_ZONE, TimeZone.current.identifier)

        if let color = color {
            values.put(CalendarContract.Calendars.CALENDAR_COLOR, hexToAndroidColor(color))
        }

        let uri = CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, "SkipCalendar")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            .build()

        guard let resultUri = contentResolver.insert(uri, values) else {
            throw CalendarError.saveFailed("Failed to create calendar")
        }

        return "\(ContentUris.parseId(resultUri))"
    }

    private func deleteAndroidCalendar(id: String) throws {
        guard let calId = Int64(id) else {
            throw CalendarError.calendarNotFound
        }
        let uri = ContentUris.withAppendedId(CalendarContract.Calendars.CONTENT_URI, calId)
        let deleted = contentResolver.delete(uri, nil, nil)
        if deleted == 0 {
            throw CalendarError.deleteFailed("Failed to delete calendar")
        }
    }

    // MARK: Android Event Operations

    private func getAndroidEvents(calendarIDs: [String]?, startDate: Date, endDate: Date) throws -> [CalendarEvent] {
        let projection = [
            CalendarContract.Events._ID,
            CalendarContract.Events.CALENDAR_ID,
            CalendarContract.Events.TITLE,
            CalendarContract.Events.EVENT_LOCATION,
            CalendarContract.Events.DESCRIPTION,
            CalendarContract.Events.DTSTART,
            CalendarContract.Events.DTEND,
            CalendarContract.Events.ALL_DAY,
            CalendarContract.Events.EVENT_TIMEZONE,
            CalendarContract.Events.AVAILABILITY,
            CalendarContract.Events.STATUS,
            CalendarContract.Events.ORGANIZER,
            CalendarContract.Events.RRULE,
            CalendarContract.Events.HAS_ALARM
        ]

        let startMillis = Int64(startDate.timeIntervalSince1970 * 1000.0)
        let endMillis = Int64(endDate.timeIntervalSince1970 * 1000.0)

        var selection = "(" + CalendarContract.Events.DTSTART + " >= ? AND " + CalendarContract.Events.DTSTART + " <= ?)"
        var selectionArgs: [String] = ["\(startMillis)", "\(endMillis)"]

        if let ids = calendarIDs, !ids.isEmpty {
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            selection = selection + " AND " + CalendarContract.Events.CALENDAR_ID + " IN (" + placeholders + ")"
            for id in ids {
                selectionArgs.append(id)
            }
        }

        guard let cursor = contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            projection.toList().toTypedArray(),
            selection,
            selectionArgs.toList().toTypedArray(),
            CalendarContract.Events.DTSTART + " ASC"
        ) else {
            return []
        }

        defer { cursor.close() }
        var results: [CalendarEvent] = []

        while cursor.moveToNext() {
            results.append(eventFromAndroidCursor(cursor))
        }

        return results
    }

    private func getAndroidEvent(id: String) throws -> CalendarEvent? {
        let projection = [
            CalendarContract.Events._ID,
            CalendarContract.Events.CALENDAR_ID,
            CalendarContract.Events.TITLE,
            CalendarContract.Events.EVENT_LOCATION,
            CalendarContract.Events.DESCRIPTION,
            CalendarContract.Events.DTSTART,
            CalendarContract.Events.DTEND,
            CalendarContract.Events.ALL_DAY,
            CalendarContract.Events.EVENT_TIMEZONE,
            CalendarContract.Events.AVAILABILITY,
            CalendarContract.Events.STATUS,
            CalendarContract.Events.ORGANIZER,
            CalendarContract.Events.RRULE,
            CalendarContract.Events.HAS_ALARM
        ]

        guard let cursor = contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            projection.toList().toTypedArray(),
            CalendarContract.Events._ID + " = ?",
            [id].toList().toTypedArray(),
            nil
        ) else {
            return nil
        }

        defer { cursor.close() }
        if cursor.moveToFirst() {
            return eventFromAndroidCursor(cursor)
        }
        return nil
    }

    private func eventFromAndroidCursor(_ cursor: android.database.Cursor) -> CalendarEvent {
        let id = "\(cursorLong(cursor, CalendarContract.Events._ID))"
        let calendarID = "\(cursorLong(cursor, CalendarContract.Events.CALENDAR_ID))"
        let title = cursorString(cursor, CalendarContract.Events.TITLE) ?? ""
        let location = cursorString(cursor, CalendarContract.Events.EVENT_LOCATION)
        let notes = cursorString(cursor, CalendarContract.Events.DESCRIPTION)
        let dtStart = cursorLong(cursor, CalendarContract.Events.DTSTART)
        let dtEnd = cursorLong(cursor, CalendarContract.Events.DTEND)
        let allDay = cursorInt(cursor, CalendarContract.Events.ALL_DAY) == 1
        let timeZone = cursorString(cursor, CalendarContract.Events.EVENT_TIMEZONE)
        let availabilityInt = cursorInt(cursor, CalendarContract.Events.AVAILABILITY)
        let statusInt = cursorInt(cursor, CalendarContract.Events.STATUS)
        let organizer = cursorString(cursor, CalendarContract.Events.ORGANIZER)
        let rruleStr = cursorString(cursor, CalendarContract.Events.RRULE)
        let hasAlarm = cursorInt(cursor, CalendarContract.Events.HAS_ALARM) == 1

        let eventStartDate = Date(timeIntervalSince1970: Double(dtStart) / 1000.0)
        let eventEndDate: Date
        if dtEnd > Int64(0) {
            eventEndDate = Date(timeIntervalSince1970: Double(dtEnd) / 1000.0)
        } else {
            eventEndDate = eventStartDate
        }

        let availability: EventAvailability
        switch availabilityInt {
        case CalendarContract.Events.AVAILABILITY_FREE: availability = .free
        case CalendarContract.Events.AVAILABILITY_TENTATIVE: availability = .tentative
        default: availability = .busy
        }

        let status: EventStatus
        switch statusInt {
        case CalendarContract.Events.STATUS_CONFIRMED: status = .confirmed
        case CalendarContract.Events.STATUS_TENTATIVE: status = .tentative
        case CalendarContract.Events.STATUS_CANCELED: status = .canceled
        default: status = .none
        }

        var recurrenceRules: [RecurrenceRule] = []
        if let rruleStr = rruleStr, !rruleStr.isEmpty {
            if let rule = RecurrenceRule.fromRRule(rruleStr) {
                recurrenceRules.append(rule)
            }
        }

        var alarms: [CalendarAlarm] = []
        if hasAlarm {
            alarms = loadAndroidReminders(eventID: id)
        }

        return CalendarEvent(
            id: id,
            calendarID: calendarID,
            title: title,
            location: location,
            notes: notes,
            startDate: eventStartDate,
            endDate: eventEndDate,
            timeZone: timeZone,
            isAllDay: allDay,
            availability: availability,
            status: status,
            alarms: alarms,
            recurrenceRules: recurrenceRules,
            organizerEmail: organizer
        )
    }

    private func loadAndroidReminders(eventID: String) -> [CalendarAlarm] {
        guard let cursor = contentResolver.query(
            CalendarContract.Reminders.CONTENT_URI,
            [CalendarContract.Reminders.MINUTES, CalendarContract.Reminders.METHOD].toList().toTypedArray(),
            CalendarContract.Reminders.EVENT_ID + " = ?",
            [eventID].toList().toTypedArray(),
            nil
        ) else {
            return []
        }

        defer { cursor.close() }
        var alarms: [CalendarAlarm] = []

        while cursor.moveToNext() {
            let minutes = cursorInt(cursor, CalendarContract.Reminders.MINUTES)
            alarms.append(CalendarAlarm(relativeOffset: Double(-minutes)))
        }

        return alarms
    }

    private func createAndroidEvent(_ event: CalendarEvent) throws -> String {
        let values = eventToAndroidContentValues(event)

        guard let uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values) else {
            throw CalendarError.saveFailed("Failed to create event")
        }

        let eventID = "\(ContentUris.parseId(uri))"
        saveAndroidReminders(eventID: eventID, alarms: event.alarms)
        return eventID
    }

    private func updateAndroidEvent(_ event: CalendarEvent) throws {
        guard let eventID = event.id, let eventIdLong = Int64(eventID) else {
            throw CalendarError.invalidData("Event ID is required for update")
        }

        let values = eventToAndroidContentValues(event)
        let uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventIdLong)
        let updated = contentResolver.update(uri, values, nil, nil)

        if updated == 0 {
            throw CalendarError.saveFailed("Failed to update event")
        }

        // Update alarms: delete old ones and add new ones
        contentResolver.delete(
            CalendarContract.Reminders.CONTENT_URI,
            CalendarContract.Reminders.EVENT_ID + " = ?",
            [eventID].toList().toTypedArray()
        )
        saveAndroidReminders(eventID: eventID, alarms: event.alarms)
    }

    private func deleteAndroidEvent(id: String) throws {
        guard let eventIdLong = Int64(id) else {
            throw CalendarError.eventNotFound
        }
        let uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventIdLong)
        let deleted = contentResolver.delete(uri, nil, nil)
        if deleted == 0 {
            throw CalendarError.deleteFailed("Failed to delete event")
        }
    }

    private func eventToAndroidContentValues(_ event: CalendarEvent) -> ContentValues {
        let values = ContentValues()

        if let calIdLong = Int64(event.calendarID) {
            values.put(CalendarContract.Events.CALENDAR_ID, calIdLong)
        }
        values.put(CalendarContract.Events.TITLE, event.title)

        if let location = event.location {
            values.put(CalendarContract.Events.EVENT_LOCATION, location)
        }
        if let notes = event.notes {
            values.put(CalendarContract.Events.DESCRIPTION, notes)
        }

        values.put(CalendarContract.Events.DTSTART, Int64(event.startDate.timeIntervalSince1970 * 1000.0))
        values.put(CalendarContract.Events.DTEND, Int64(event.endDate.timeIntervalSince1970 * 1000.0))
        values.put(CalendarContract.Events.ALL_DAY, event.isAllDay ? 1 : 0)
        values.put(CalendarContract.Events.EVENT_TIMEZONE, event.timeZone ?? TimeZone.current.identifier)

        switch event.availability {
        case .free: values.put(CalendarContract.Events.AVAILABILITY, CalendarContract.Events.AVAILABILITY_FREE)
        case .tentative: values.put(CalendarContract.Events.AVAILABILITY, CalendarContract.Events.AVAILABILITY_TENTATIVE)
        default: values.put(CalendarContract.Events.AVAILABILITY, CalendarContract.Events.AVAILABILITY_BUSY)
        }

        if let firstRule = event.recurrenceRules.first {
            values.put(CalendarContract.Events.RRULE, firstRule.toRRule())
        }

        return values
    }

    private func saveAndroidReminders(eventID: String, alarms: [CalendarAlarm]) {
        for alarm in alarms {
            let values = ContentValues()
            if let eventIdLong = Int64(eventID) {
                values.put(CalendarContract.Reminders.EVENT_ID, eventIdLong)
            }
            let minutes: Int
            if alarm.relativeOffset < 0.0 {
                minutes = Int(-alarm.relativeOffset)
            } else {
                minutes = Int(alarm.relativeOffset)
            }
            values.put(CalendarContract.Reminders.MINUTES, minutes)
            values.put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
            contentResolver.insert(CalendarContract.Reminders.CONTENT_URI, values)
        }
    }

    // MARK: Android Attendee Operations

    private func getAndroidAttendees(eventID: String) throws -> [CalendarAttendee] {
        guard let cursor = contentResolver.query(
            CalendarContract.Attendees.CONTENT_URI,
            [
                CalendarContract.Attendees._ID,
                CalendarContract.Attendees.ATTENDEE_NAME,
                CalendarContract.Attendees.ATTENDEE_EMAIL,
                CalendarContract.Attendees.ATTENDEE_RELATIONSHIP,
                CalendarContract.Attendees.ATTENDEE_STATUS,
                CalendarContract.Attendees.ATTENDEE_TYPE
            ].toList().toTypedArray(),
            CalendarContract.Attendees.EVENT_ID + " = ?",
            [eventID].toList().toTypedArray(),
            nil
        ) else {
            return []
        }

        defer { cursor.close() }
        var results: [CalendarAttendee] = []

        while cursor.moveToNext() {
            let id = "\(cursorLong(cursor, CalendarContract.Attendees._ID))"
            let name = cursorString(cursor, CalendarContract.Attendees.ATTENDEE_NAME)
            let email = cursorString(cursor, CalendarContract.Attendees.ATTENDEE_EMAIL)
            let relationship = cursorInt(cursor, CalendarContract.Attendees.ATTENDEE_RELATIONSHIP)
            let statusInt = cursorInt(cursor, CalendarContract.Attendees.ATTENDEE_STATUS)
            let typeInt = cursorInt(cursor, CalendarContract.Attendees.ATTENDEE_TYPE)

            let role: AttendeeRole
            switch relationship {
            case CalendarContract.Attendees.RELATIONSHIP_ORGANIZER: role = .organizer
            case CalendarContract.Attendees.RELATIONSHIP_ATTENDEE: role = .required
            case CalendarContract.Attendees.RELATIONSHIP_PERFORMER: role = .required
            case CalendarContract.Attendees.RELATIONSHIP_SPEAKER: role = .required
            default: role = .unknown
            }

            let status: AttendeeStatus
            switch statusInt {
            case CalendarContract.Attendees.ATTENDEE_STATUS_ACCEPTED: status = .accepted
            case CalendarContract.Attendees.ATTENDEE_STATUS_DECLINED: status = .declined
            case CalendarContract.Attendees.ATTENDEE_STATUS_TENTATIVE: status = .tentative
            case CalendarContract.Attendees.ATTENDEE_STATUS_INVITED: status = .pending
            default: status = .unknown
            }

            let atype: AttendeeType
            switch typeInt {
            case CalendarContract.Attendees.TYPE_REQUIRED: atype = .person
            case CalendarContract.Attendees.TYPE_OPTIONAL: atype = .person
            case CalendarContract.Attendees.TYPE_RESOURCE: atype = .resource
            default: atype = .unknown
            }

            results.append(CalendarAttendee(
                id: id,
                name: name,
                email: email,
                role: role,
                status: status,
                type: atype,
                isCurrentUser: false
            ))
        }

        return results
    }

    // MARK: Android Color Utilities

    private func androidColorToHex(_ color: Int) -> String {
        let r = (color >> 16) & 0xFF
        let g = (color >> 8) & 0xFF
        let b = color & 0xFF
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func hexToAndroidColor(_ hex: String) -> Int {
        var hexString = hex
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst())
        }
        return android.graphics.Color.parseColor("#" + hexString)
    }

    private func androidAccessLevel(_ level: Int) -> CalendarAccessLevel {
        switch level {
        case CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR: return .contributor
        case CalendarContract.Calendars.CAL_ACCESS_EDITOR: return .editor
        case CalendarContract.Calendars.CAL_ACCESS_FREEBUSY: return .freebusy
        case CalendarContract.Calendars.CAL_ACCESS_OWNER: return .owner
        case CalendarContract.Calendars.CAL_ACCESS_READ: return .read
        case CalendarContract.Calendars.CAL_ACCESS_RESPOND: return .respond
        case CalendarContract.Calendars.CAL_ACCESS_ROOT: return .root
        default: return .none
        }
    }
    #endif
}

#endif
