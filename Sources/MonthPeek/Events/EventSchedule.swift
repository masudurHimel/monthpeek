import Foundation

/// Pure logic behind the events band and the grid dots. No EventKit, no
/// AppKit, so every rule here is unit tested.
enum EventSchedule {
    enum DotStyle: Equatable {
        case none
        case calendar(EventColor)
        case mixed
    }

    /// Buckets events by the start of each day they touch. An event covers a
    /// day when it starts before that day ends and ends after that day
    /// starts — so an end exactly at midnight does not spill into the next
    /// day, while EventKit's 23:59:59 all-day end does count. Each bucket is
    /// sorted with `sorted(_:)`.
    static func group(_ events: [EventItem], calendar: Calendar) -> [Date: [EventItem]] {
        var buckets: [Date: [EventItem]] = [:]
        for event in events {
            var day = calendar.startOfDay(for: event.start)
            let lastInclusive = max(event.end, event.start)
            repeat {
                buckets[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            } while day < lastInclusive
        }
        return buckets.mapValues(sorted)
    }

    /// Replace the cached days that fall inside `window` with the freshly
    /// fetched ones. Days outside the window are left alone — including
    /// partial entries the fetch produced for multi-day events that start
    /// before the window — so an older fetch can never wipe newer data.
    static func merge(
        _ cache: [Date: [EventItem]], with fetched: [Date: [EventItem]],
        window: Range<Date>, calendar: Calendar
    ) -> [Date: [EventItem]] {
        var merged = cache.filter { !window.contains($0.key) }
        for (day, events) in fetched where window.contains(day) {
            merged[day] = events
        }
        return merged
    }

    /// All-day events first, then by start time, then by title.
    static func sorted(_ events: [EventItem]) -> [EventItem] {
        events.sorted { a, b in
            if a.isAllDay != b.isAllDay { return a.isAllDay }
            if !a.isAllDay, a.start != b.start { return a.start < b.start }
            return a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }

    static func dotStyle(for events: [EventItem]) -> DotStyle {
        guard let first = events.first else { return .none }
        return events.allSatisfy { $0.calendarID == first.calendarID } ? .calendar(first.color) : .mixed
    }

    /// Which row today's list should start scrolled to: the first timed
    /// event that has not ended yet (so one in progress stays visible), or
    /// the last event when everything is over. Other days start at the top.
    static func initialAnchor(in events: [EventItem], now: Date, isToday: Bool) -> EventItem.ID? {
        guard isToday, !events.isEmpty else { return nil }
        if let upcoming = events.first(where: { !$0.isAllDay && $0.end > now }) {
            return upcoming.id
        }
        return events.last?.id
    }

    /// Same day number in the target month, clamped to that month's length.
    static func followSelection(_ selected: Date, intoMonth month: Date, calendar: Calendar) -> Date {
        let day = calendar.component(.day, from: selected)
        var components = calendar.dateComponents([.year, .month], from: month)
        let firstOfMonth = calendar.date(from: components)!
        let length = calendar.range(of: .day, in: .month, for: firstOfMonth)!.count
        components.day = min(day, length)
        return calendar.date(from: components)!
    }
}

/// Sizes for the events band. Everything derives from the same width-based
/// scale factor the grid uses, and `height(forRows:)` is the single formula
/// both the SwiftUI layout and the window-frame code rely on.
struct BandMetrics {
    static let maxVisibleRows = 4

    /// The panel's width-derived scale factor, shared with the grid's
    /// `Metrics` so both regions size their type and spacing identically.
    static func scale(forPanelWidth width: CGFloat) -> CGFloat {
        max(0.8, min(2.2, width / 300))
    }

    let scale: CGFloat

    var topPadding: CGFloat { 9 * scale }
    var bottomPadding: CGFloat { 11 * scale }
    var horizontalPadding: CGFloat { 14 * scale }
    var headerHeight: CGFloat { 16 * scale }
    var headerGap: CGFloat { 6 * scale }
    var rowHeight: CGFloat { 34 * scale }
    var rowSpacing: CGFloat { 2 * scale }
    var peekHeight: CGFloat { 14 * scale }

    var barWidth: CGFloat { 3 * scale }
    var barHeight: CGFloat { 24 * scale }
    var timeColumnWidth: CGFloat { 46 * scale }
    var columnGap: CGFloat { 9 * scale }

    var dateFontSize: CGFloat { 11.5 * scale }
    var countFontSize: CGFloat { 10.5 * scale }
    var timeFontSize: CGFloat { 11 * scale }
    var endTimeFontSize: CGFloat { 9.5 * scale }
    var allDayFontSize: CGFloat { 9.5 * scale }
    var titleFontSize: CGFloat { 12 * scale }
    var calendarFontSize: CGFloat { 10 * scale }
    var emptyFontSize: CGFloat { 12 * scale }

    /// Height of the rows region only (what the list scrolls inside).
    func rowsHeight(forRows count: Int) -> CGFloat {
        let visible = max(1, min(count, Self.maxVisibleRows))
        var height = CGFloat(visible) * rowHeight + CGFloat(visible - 1) * rowSpacing
        if count > Self.maxVisibleRows { height += rowSpacing + peekHeight }
        return height
    }

    func height(forRows count: Int) -> CGFloat {
        topPadding + headerHeight + headerGap + rowsHeight(forRows: count) + bottomPadding
    }
}
