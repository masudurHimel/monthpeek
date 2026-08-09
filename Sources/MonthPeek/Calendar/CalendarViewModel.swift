import AppKit
import SwiftUI

/// Drives the displayed month and its slide direction. Owned by the
/// PanelController so scroll events and day changes reach the SwiftUI
/// content without the view hierarchy knowing about AppKit.
final class CalendarViewModel: ObservableObject {
    enum Direction { case forward, backward, none }

    /// First day of the month currently shown.
    @Published private(set) var displayedMonth: Date
    @Published private(set) var direction: Direction = .none
    @Published private(set) var today: Date

    /// Drives the pop-in/out animation of the card. The PanelController
    /// flips this right after ordering the window in (and before ordering
    /// it out), so the card grows down from the menu bar and retracts back
    /// up into it.
    @Published var isPresented = false

    private var scrollAccumulator: CGFloat = 0

    init() {
        displayedMonth = Self.firstOfMonth(containing: Date())
        today = Calendar.current.startOfDay(for: Date())
    }

    static func firstOfMonth(containing date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    func nextMonth() { navigate(by: 1) }
    func previousMonth() { navigate(by: -1) }

    func goToToday() {
        today = Calendar.current.startOfDay(for: Date())
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
        direction = .none
        displayedMonth = Self.firstOfMonth(containing: today)
        scrollAccumulator = 0
    }

    func dayChanged() {
        today = Calendar.current.startOfDay(for: Date())
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
        direction = months > 0 ? .forward : .backward
        let target = Calendar.current.date(byAdding: .month, value: months, to: displayedMonth)!
        withAnimation(.spring(duration: 0.3)) {
            displayedMonth = target
        }
    }
}
