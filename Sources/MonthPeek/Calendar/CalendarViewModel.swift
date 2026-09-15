import AppKit
import Combine
import SwiftUI

/// Drives the displayed month, the selected day, and its slide direction.
/// Owned by the PanelController so scroll events and day changes reach the
/// SwiftUI content without the view hierarchy knowing about AppKit.
///
/// When the events feature is on it also caches the events for the visible
/// six weeks and republishes them keyed by day.
final class CalendarViewModel: ObservableObject {
    enum Direction { case forward, backward, none }

    /// First day of the month currently shown.
    @Published private(set) var displayedMonth: Date
    @Published private(set) var direction: Direction = .none
    @Published private(set) var today: Date
    /// Start of the selected day. Today whenever the panel opens.
    @Published private(set) var selectedDate: Date

    /// Drives the pop-in/out animation of the card. The PanelController
    /// flips this right after ordering the window in (and before ordering
    /// it out), so the card grows down from the menu bar and retracts back
    /// up into it.
    @Published var isPresented = false

    // MARK: Events

    /// True when the toggle is on and calendar access is granted.
    @Published private(set) var eventsEnabled = false
    @Published private(set) var showDots = false
    @Published private(set) var eventsByDay: [Date: [EventItem]] = [:]

    var selectedEvents: [EventItem] { eventsByDay[selectedDate] ?? [] }

    private let eventStore: EventStoreService
    private var settings = EventSettings.current
    private var cancellables = Set<AnyCancellable>()
    private var scrollAccumulator: CGFloat = 0

    init(eventStore: EventStoreService = .shared) {
        self.eventStore = eventStore
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        displayedMonth = Self.firstOfMonth(containing: now)
        today = startOfToday
        selectedDate = startOfToday
        bindEvents()
    }

    static func firstOfMonth(containing date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    // MARK: - Navigation

    func nextMonth() { navigate(by: 1) }
    func previousMonth() { navigate(by: -1) }

    func goToToday() {
        today = Calendar.current.startOfDay(for: Date())
        selectedDate = today
        let target = Self.firstOfMonth(containing: today)
        guard target != displayedMonth else { return }
        direction = target > displayedMonth ? .forward : .backward
        withAnimation(.spring(duration: 0.3)) {
            displayedMonth = target
        }
    }

    /// Snap back to the current month without animation (used when the
    /// panel opens).
    func resetToToday() {
        today = Calendar.current.startOfDay(for: Date())
        selectedDate = today
        direction = .none
        displayedMonth = Self.firstOfMonth(containing: today)
        scrollAccumulator = 0
    }

    func dayChanged() {
        today = Calendar.current.startOfDay(for: Date())
    }

    /// Select a day. Clicking a dimmed adjacent-month day also slides the
    /// grid to that month.
    func select(_ date: Date) {
        let calendar = Calendar.current
        selectedDate = calendar.startOfDay(for: date)
        let month = Self.firstOfMonth(containing: selectedDate, calendar: calendar)
        guard month != displayedMonth else { return }
        direction = month > displayedMonth ? .forward : .backward
        withAnimation(.spring(duration: 0.3)) {
            displayedMonth = month
        }
    }

    func handleScroll(_ event: NSEvent) {
        // Momentum events after a trackpad flick would fire several extra
        // month changes; only honor the gesture itself.
        guard event.momentumPhase.isEmpty else { return }
        if event.phase == .began { scrollAccumulator = 0 }

        var delta = event.scrollingDeltaY
        if abs(event.scrollingDeltaX) > abs(delta) { delta = event.scrollingDeltaX }
        if !event.hasPreciseScrollingDeltas { delta *= 12 }
        scrollAccumulator += delta

        let threshold: CGFloat = 60
        if scrollAccumulator <= -threshold {
            scrollAccumulator = 0
            nextMonth()
        } else if scrollAccumulator >= threshold {
            scrollAccumulator = 0
            previousMonth()
        }
    }

    private func navigate(by months: Int) {
        let calendar = Calendar.current
        direction = months > 0 ? .forward : .backward
        let target = calendar.date(byAdding: .month, value: months, to: displayedMonth)!
        selectedDate = EventSchedule.followSelection(selectedDate, intoMonth: target, calendar: calendar)
        withAnimation(.spring(duration: 0.3)) {
            displayedMonth = target
        }
    }

    // MARK: - Events

    private func bindEvents() {
        eventsEnabled = eventStore.isEnabled
        showDots = settings.showDots

        // Authorization changes and database changes both mean "refetch".
        eventStore.$status
            .map { _ in () }
            .merge(with: eventStore.$changeToken.map { _ in () })
            .dropFirst(2)  // skip the initial values replayed by @Published
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applySettings(force: true) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applySettings(force: false) }
            .store(in: &cancellables)

        // @Published emits from willSet, so read the month from the value
        // delivered here — `self.displayedMonth` is still the old one.
        $displayedMonth
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] month in self?.reloadEvents(for: month) }
            .store(in: &cancellables)

        reloadEvents()
    }

    /// Re-read the settings snapshot; only react when something relevant to
    /// events changed (the panel size is also stored in UserDefaults).
    private func applySettings(force: Bool) {
        let fresh = EventSettings.current
        let enabled = eventStore.isEnabled
        guard force || fresh != settings || enabled != eventsEnabled else { return }
        settings = fresh
        if enabled != eventsEnabled { eventsEnabled = enabled }
        if fresh.showDots != showDots { showDots = fresh.showDots }
        // Hidden calendars or the store itself changed: every cached month
        // is suspect, so start over from the visible one.
        eventsByDay = [:]
        reloadEvents()
    }

    /// Fetch the six visible weeks (plus slack for either week-start
    /// setting) and merge them into the per-day cache. Fetches are never
    /// cancelled: each one only replaces the days of its own window, so a
    /// slow fetch can neither wipe newer data nor leave a month empty, and
    /// months already visited show instantly when navigating back.
    func reloadEvents(for month: Date? = nil) {
        let month = month ?? displayedMonth
        guard eventsEnabled else {
            if !eventsByDay.isEmpty { eventsByDay = [:] }
            return
        }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -7, to: month)!
        let end = calendar.date(byAdding: .day, value: 49, to: month)!
        let hidden = settings.hiddenCalendarIDs
        let store = eventStore
        Task { @MainActor [weak self] in
            let items = await store.events(from: start, to: end, excluding: hidden)
            guard let self, self.eventsEnabled, self.settings.hiddenCalendarIDs == hidden else { return }
            let fetched = EventSchedule.group(items, calendar: calendar)
            self.eventsByDay = EventSchedule.merge(self.eventsByDay, with: fetched, window: start..<end, calendar: calendar)
        }
    }
}
