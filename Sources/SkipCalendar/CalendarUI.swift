// Copyright 2025–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import Foundation
import SwiftUI

#if SKIP
import android.content.Context
import android.content.Intent
import android.content.ContentUris
import android.provider.CalendarContract
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
#else
#if os(iOS)
import EventKit
import EventKitUI
#endif
#endif

extension View {
    /// Present the native event editor interface.
    ///
    /// On iOS, this presents an `EKEventEditViewController` in a sheet.
    /// On Android, this launches an `ACTION_INSERT` or `ACTION_EDIT` intent to the system calendar app.
    ///
    /// - Parameters:
    ///   - isPresented: A binding that controls whether the editor is shown.
    ///   - options: Configuration for the editor (existing event to edit, or defaults for a new event).
    ///   - onComplete: Called when the editor finishes, with the result status.
    @ViewBuilder public func withEventEditor(
        isPresented: Binding<Bool>,
        options: EventEditorOptions = EventEditorOptions(),
        onComplete: ((EventEditorResult) -> Void)? = nil
    ) -> some View {
        #if SKIP
        let context = LocalContext.current

        return onChange(of: isPresented.wrappedValue) { oldValue, presented in
            if presented == true {
                isPresented.wrappedValue = false
                launchEventEditorIntent(context: context, options: options)
                onComplete?(.unknown)
            }
        }
        #else
        #if os(iOS)
        sheet(isPresented: isPresented) {
            EventEditRepresentable(
                options: options,
                isPresented: isPresented,
                onComplete: onComplete
            )
        }
        #else
        self
        #endif
        #endif
    }

    /// Present the native event viewer interface.
    ///
    /// On iOS, this presents an `EKEventViewController` in a sheet.
    /// On Android, this launches an `ACTION_VIEW` intent to the system calendar app.
    ///
    /// - Parameters:
    ///   - isPresented: A binding that controls whether the viewer is shown.
    ///   - eventID: The ID of the event to view.
    ///   - onComplete: Called when the viewer is dismissed, with the result status.
    @ViewBuilder public func withEventViewer(
        isPresented: Binding<Bool>,
        eventID: String,
        onComplete: ((EventEditorResult) -> Void)? = nil
    ) -> some View {
        #if SKIP
        let context = LocalContext.current

        return onChange(of: isPresented.wrappedValue) { oldValue, presented in
            if presented == true {
                isPresented.wrappedValue = false
                launchEventViewIntent(context: context, eventID: eventID)
                onComplete?(.unknown)
            }
        }
        #else
        #if os(iOS)
        sheet(isPresented: isPresented) {
            EventViewRepresentable(
                eventID: eventID,
                isPresented: isPresented,
                onComplete: onComplete
            )
        }
        #else
        self
        #endif
        #endif
    }
}

// MARK: - Android Intent Launchers

#if SKIP
private func launchEventEditorIntent(context: Context, options: EventEditorOptions) {
    if let event = options.event, let eventID = event.id, let eventIdLong = Int64(eventID) {
        // Edit existing event
        let uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventIdLong)
        let intent = Intent(Intent.ACTION_EDIT)
        intent.setData(uri)
        intent.putExtra(CalendarContract.Events.TITLE, event.title)
        context.startActivity(intent)
    } else {
        // Create new event
        let intent = Intent(Intent.ACTION_INSERT)
        intent.setData(CalendarContract.Events.CONTENT_URI)

        let title = options.defaultTitle ?? options.event?.title
        if let title = title {
            intent.putExtra(CalendarContract.Events.TITLE, title)
        }
        let location = options.defaultLocation ?? options.event?.location
        if let location = location {
            intent.putExtra(CalendarContract.Events.EVENT_LOCATION, location)
        }
        let notes = options.defaultNotes ?? options.event?.notes
        if let notes = notes {
            intent.putExtra(CalendarContract.Events.DESCRIPTION, notes)
        }
        let startDate = options.defaultStartDate ?? options.event?.startDate
        if let startDate = startDate {
            intent.putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, Int64(startDate.timeIntervalSince1970 * 1000.0))
        }
        let endDate = options.defaultEndDate ?? options.event?.endDate
        if let endDate = endDate {
            intent.putExtra(CalendarContract.EXTRA_EVENT_END_TIME, Int64(endDate.timeIntervalSince1970 * 1000.0))
        }
        let allDay = options.defaultAllDay || (options.event?.isAllDay == true)
        intent.putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, allDay)

        context.startActivity(intent)
    }
}

private func launchEventViewIntent(context: Context, eventID: String) {
    if let eventIdLong = Int64(eventID) {
        let uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventIdLong)
        let intent = Intent(Intent.ACTION_VIEW)
        intent.setData(uri)
        context.startActivity(intent)
    }
}
#endif

// MARK: - iOS UIViewControllerRepresentable

#if !SKIP
#if os(iOS)

struct EventEditRepresentable : UIViewControllerRepresentable {
    let options: EventEditorOptions
    @Binding var isPresented: Bool
    let onComplete: ((EventEditorResult) -> Void)?

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let vc = EKEventEditViewController()
        let store = CalendarManager.shared.eventStore
        vc.eventStore = store
        vc.editViewDelegate = context.coordinator

        if let existingEvent = options.event, let eventID = existingEvent.id {
            vc.event = store.event(withIdentifier: eventID)
        } else {
            let newEvent = EKEvent(eventStore: store)
            newEvent.title = options.defaultTitle ?? options.event?.title ?? ""
            newEvent.location = options.defaultLocation ?? options.event?.location
            newEvent.notes = options.defaultNotes ?? options.event?.notes
            newEvent.startDate = options.defaultStartDate ?? options.event?.startDate ?? Date()
            newEvent.endDate = options.defaultEndDate ?? options.event?.endDate ?? Date().addingTimeInterval(3600)
            newEvent.isAllDay = options.defaultAllDay

            if let calID = options.defaultCalendarID {
                newEvent.calendar = store.calendar(withIdentifier: calID)
            }
            if newEvent.calendar == nil {
                newEvent.calendar = store.defaultCalendarForNewEvents
            }

            vc.event = newEvent
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator : NSObject, EKEventEditViewDelegate {
        let parent: EventEditRepresentable

        init(parent: EventEditRepresentable) {
            self.parent = parent
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            let result: EventEditorResult
            switch action {
            case .saved: result = .saved
            case .deleted: result = .deleted
            case .canceled: result = .canceled
            @unknown default: result = .unknown
            }
            parent.onComplete?(result)
            parent.isPresented = false
        }
    }
}

struct EventViewRepresentable : UIViewControllerRepresentable {
    let eventID: String
    @Binding var isPresented: Bool
    let onComplete: ((EventEditorResult) -> Void)?

    func makeUIViewController(context: Context) -> UINavigationController {
        let store = CalendarManager.shared.eventStore
        let vc = EKEventViewController()
        vc.event = store.event(withIdentifier: eventID)
        vc.allowsEditing = true
        vc.delegate = context.coordinator
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator : NSObject, EKEventViewDelegate {
        let parent: EventViewRepresentable

        init(parent: EventViewRepresentable) {
            self.parent = parent
        }

        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            let result: EventEditorResult
            switch action {
            case .done: result = .saved
            case .deleted: result = .deleted
            case .responded: result = .saved
            @unknown default: result = .unknown
            }
            parent.onComplete?(result)
            parent.isPresented = false
        }
    }
}

#endif
#endif

#endif
