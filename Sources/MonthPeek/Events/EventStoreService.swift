import AppKit
import EventKit

/// The only place MonthPeek touches EventKit. Read-only by construction:
/// there is no method here that saves, removes, or commits anything.
///
/// Creating an `EKEventStore` never prompts; only `requestAccess()` does,
/// and it is called solely from the "Show calendar events" toggle.
///
/// Used from the main thread only (its published properties feed SwiftUI);
/// the one blocking EventKit query is pushed to a background task.
final class EventStoreService: ObservableObject {
    static let shared = EventStoreService()

    @Published private(set) var status: EKAuthorizationStatus
    @Published private(set) var calendars: [CalendarInfo] = []
    /// Increments whenever EventKit reports the calendar database changed
    /// (an edit in Calendar.app, a sync, a calendar added or removed).
    @Published private(set) var changeToken = 0

    /// Lazy so EventKit is never touched while the feature is off: `init`
    /// only reads the static authorization status.
    private lazy var store = EKEventStore()
    private var observer: NSObjectProtocol?

    var hasFullAccess: Bool { status == .fullAccess }

    /// The user (or a profile) said no; asking again will not prompt.
    var isBlocked: Bool {
        switch status {
        case .denied, .restricted, .writeOnly: return true
        default: return false
        }
    }

    /// The feature is effectively on only when the toggle is on *and* the
    /// user granted full access.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.showEvents) && hasFullAccess
    }

    private init() {
        status = EKEventStore.authorizationStatus(for: .event)
        if hasFullAccess { startObserving() }
    }

    // MARK: - Authorization

    /// Requests full (read) access. Returns whether access is now granted.
    /// A previously denied app gets `false` back without a new prompt; the
    /// caller points the user at System Settings in that case.
    @discardableResult
    @MainActor
    func requestAccess() async -> Bool {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            // Treated as denied below.
        }
        status = EKEventStore.authorizationStatus(for: .event)
        if hasFullAccess { startObserving() }
        return hasFullAccess
    }

    /// The toggle is stored on but the system has never asked (e.g. the
    /// privacy database was reset by an ad-hoc rebuild). Ask now.
    func requestAccessIfWanted() {
        guard UserDefaults.standard.bool(forKey: SettingsKey.showEvents), status == .notDetermined else { return }
        Task { await requestAccess() }
    }

    static func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Reading

    /// Ask EventKit to pull any pending changes from the calendar servers.
    /// Results arrive through the store-changed notification, which triggers
    /// a refetch. Called when the panel opens so a peek is as fresh as
    /// Calendar.app itself.
    func refreshSources() {
        guard hasFullAccess else { return }
        store.refreshSourcesIfNecessary()
    }

    /// Every event overlapping `[start, end)` from calendars not in `hidden`.
    /// The store query is synchronous, so it runs off the main thread and
    /// hands back plain values.
    func events(from start: Date, to end: Date, excluding hidden: Set<String>) async -> [EventItem] {
        guard hasFullAccess else { return [] }
        let calendars = store.calendars(for: .event).filter { !hidden.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let store = self.store
        return await Task.detached(priority: .userInitiated) {
            store.events(matching: predicate).map(EventItem.init)
        }.value
    }

    private func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            self?.storeChanged()
        }
        reloadCalendars()
    }

    private func storeChanged() {
        reloadCalendars()
        changeToken += 1
    }

    private func reloadCalendars() {
        calendars = store.calendars(for: .event)
            .map(CalendarInfo.init)
            .sorted {
                if $0.sourceTitle != $1.sourceTitle {
                    return $0.sourceTitle.localizedStandardCompare($1.sourceTitle) == .orderedAscending
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }
}

// MARK: - EventKit → plain values

extension CalendarInfo {
    init(_ calendar: EKCalendar) {
        let kind: Kind
        switch calendar.type {
        case .birthday: kind = .birthday
        case .subscription: kind = .subscribed
        default: kind = calendar.source?.sourceType == .subscribed ? .subscribed : .regular
        }
        self.init(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source?.title ?? "Other",
            color: EventColor(cgColor: calendar.cgColor),
            kind: kind
        )
    }
}

extension EventItem {
    init(_ event: EKEvent) {
        let calendar = event.calendar
        // Recurring events share an eventIdentifier; the occurrence date
        // makes each instance unique for SwiftUI's ForEach.
        let occurrence = event.occurrenceDate ?? event.startDate ?? Date()
        let identifier = event.calendarItemIdentifier
        self.init(
            id: "\(identifier)@\(occurrence.timeIntervalSince1970)",
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Untitled",
            start: event.startDate ?? Date(),
            end: event.endDate ?? event.startDate ?? Date(),
            isAllDay: event.isAllDay,
            calendarID: calendar?.calendarIdentifier ?? "",
            calendarTitle: calendar?.title ?? "",
            color: EventColor(cgColor: calendar?.cgColor),
            eventIdentifier: identifier,
            occurrence: occurrence
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
