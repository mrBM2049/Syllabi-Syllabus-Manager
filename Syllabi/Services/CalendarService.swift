import Foundation
import EventKit
import Combine

public final class CalendarService: ObservableObject, @unchecked Sendable {
    public static let shared = CalendarService()

    private let eventStore = EKEventStore()

    @Published public var isAuthorized: Bool = false
    @Published public var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published public var dayEvents: [EKEvent] = []

    public init() {
        checkAuthorization()
    }

    public func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        self.authorizationStatus = status
        if #available(macOS 14.0, *) {
            self.isAuthorized = (status == .fullAccess)
        } else {
            self.isAuthorized = (status == .authorized)
        }
    }

    public func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.isAuthorized = granted
                    self.checkAuthorization()
                }
                return granted
            } catch {
                print("Failed to request full calendar access: \(error)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    Task { @MainActor in
                        self.isAuthorized = granted
                        self.checkAuthorization()
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    /// Schedules a study task/topic directly into the student's macOS Calendar
    @discardableResult
    public func scheduleStudyTask(
        title: String,
        courseName: String,
        notes: String,
        startDate: Date,
        durationMinutes: Int = 45
    ) async throws -> EKEvent {
        if !isAuthorized {
            let granted = await requestAccess()
            guard granted else {
                throw NSError(domain: "CalendarService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar permission not granted."])
            }
        }

        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            throw NSError(domain: "CalendarService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No default calendar found on this Mac."])
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = "[\(courseName)] \(title)"
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.calendar = defaultCalendar

        var fullNotes = "Syllabi Study Session\nCourse: \(courseName)\nTopic: \(title)"
        if !notes.isEmpty {
            fullNotes += "\n\nNotes:\n\(notes)"
        }
        event.notes = fullNotes

        try eventStore.save(event, span: .thisEvent)

        // Refresh events for the day
        await loadEvents(for: startDate)

        return event
    }

    /// Loads events for a specific date from macOS Calendar
    @MainActor
    public func loadEvents(for date: Date) {
        guard isAuthorized else {
            dayEvents = []
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        self.dayEvents = events.sorted { $0.startDate < $1.startDate }
    }
}
