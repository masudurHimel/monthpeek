import Foundation
import Testing

@testable import MonthPeek

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}()

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
}

private let blue = EventColor(red: 0.1, green: 0.7, blue: 1)
private let green = EventColor(red: 0.4, green: 0.85, blue: 0.2)

private func event(
    _ title: String, start: Date, end: Date, allDay: Bool = false,
    calendar: String = "work", color: EventColor = blue
) -> EventItem {
    EventItem(
        id: "\(title)-\(start.timeIntervalSince1970)", title: title, start: start, end: end,
        isAllDay: allDay, calendarID: calendar, calendarTitle: calendar.capitalized, color: color
    )
}

// MARK: - Grouping

@Test func timedEventLandsOnItsStartDay() {
    let e = event("Standup", start: at(2026, 9, 15, 9, 30), end: at(2026, 9, 15, 10))
    let grouped = EventSchedule.group([e], calendar: utc)
    #expect(grouped.keys.sorted() == [at(2026, 9, 15)])
    #expect(grouped[at(2026, 9, 15)] == [e])
}

@Test func eventCrossingMidnightAppearsOnBothDays() {
    let e = event("Red-eye", start: at(2026, 9, 15, 22), end: at(2026, 9, 16, 2))
    let grouped = EventSchedule.group([e], calendar: utc)
    #expect(grouped.keys.sorted() == [at(2026, 9, 15), at(2026, 9, 16)])
}

@Test func eventEndingExactlyAtMidnightDoesNotSpillOver() {
    let e = event("Late", start: at(2026, 9, 15, 23), end: at(2026, 9, 16))
    let grouped = EventSchedule.group([e], calendar: utc)
    #expect(grouped.keys.sorted() == [at(2026, 9, 15)])
}

@Test func allDayEventWithEventKitStyleEndStaysOnOneDay() {
    // EventKit ends single all-day events at 23:59:59 of the same day.
    let e = event("Holiday", start: at(2026, 9, 7), end: at(2026, 9, 7, 23, 59, 59), allDay: true)
    let grouped = EventSchedule.group([e], calendar: utc)
    #expect(grouped.keys.sorted() == [at(2026, 9, 7)])
}

@Test func multiDayAllDayEventCoversEveryDay() {
    let e = event("Offsite", start: at(2026, 9, 14), end: at(2026, 9, 16, 23, 59, 59), allDay: true)
    let grouped = EventSchedule.group([e], calendar: utc)
    #expect(grouped.keys.sorted() == [at(2026, 9, 14), at(2026, 9, 15), at(2026, 9, 16)])
}

@Test func zeroDurationEventStillAppears() {
    let e = event("Ping", start: at(2026, 9, 15, 12), end: at(2026, 9, 15, 12))
    let grouped = EventSchedule.group([e], calendar: utc)
    #expect(grouped[at(2026, 9, 15)] == [e])
}

// MARK: - Ordering

@Test func allDayEventsSortFirstThenByStartThenTitle() {
    let dinner = event("Dinner", start: at(2026, 9, 15, 19, 30), end: at(2026, 9, 15, 21))
    let standup = event("Standup", start: at(2026, 9, 15, 9, 30), end: at(2026, 9, 15, 10))
    let review = event("Review week", start: at(2026, 9, 15), end: at(2026, 9, 15, 23, 59, 59), allDay: true)
    let deploy = event("Deploy freeze", start: at(2026, 9, 15), end: at(2026, 9, 15, 23, 59, 59), allDay: true)
    let dentist = event("Dentist", start: at(2026, 9, 15, 9, 30), end: at(2026, 9, 15, 10))

    let sorted = EventSchedule.sorted([dinner, standup, review, deploy, dentist])
    #expect(sorted.map(\.title) == ["Deploy freeze", "Review week", "Dentist", "Standup", "Dinner"])
}

@Test func groupingSortsEachDay() {
    let late = event("Late", start: at(2026, 9, 15, 20), end: at(2026, 9, 15, 21))
    let early = event("Early", start: at(2026, 9, 15, 8), end: at(2026, 9, 15, 9))
    let grouped = EventSchedule.group([late, early], calendar: utc)
    #expect(grouped[at(2026, 9, 15)]?.map(\.title) == ["Early", "Late"])
}

// MARK: - Dot style

@Test func noEventsMeansNoDot() {
    #expect(EventSchedule.dotStyle(for: []) == .none)
}

@Test func singleCalendarDotUsesThatCalendarsColor() {
    let a = event("A", start: at(2026, 9, 15, 9), end: at(2026, 9, 15, 10))
    let b = event("B", start: at(2026, 9, 15, 11), end: at(2026, 9, 15, 12))
    #expect(EventSchedule.dotStyle(for: [a, b]) == .calendar(blue))
}

@Test func mixedCalendarsGiveNeutralDot() {
    let a = event("A", start: at(2026, 9, 15, 9), end: at(2026, 9, 15, 10))
    let b = event("B", start: at(2026, 9, 15, 11), end: at(2026, 9, 15, 12), calendar: "home", color: green)
    #expect(EventSchedule.dotStyle(for: [a, b]) == .mixed)
}

// MARK: - Selection follow

@Test func selectionKeepsDayNumberInNewMonth() {
    let moved = EventSchedule.followSelection(at(2026, 9, 15), intoMonth: at(2026, 10, 1), calendar: utc)
    #expect(moved == at(2026, 10, 15))
}

@Test func selectionClampsToLastDayOfShorterMonth() {
    let moved = EventSchedule.followSelection(at(2026, 1, 31), intoMonth: at(2026, 2, 1), calendar: utc)
    #expect(moved == at(2026, 2, 28))
}

@Test func selectionClampsInLeapFebruary() {
    let moved = EventSchedule.followSelection(at(2028, 3, 31), intoMonth: at(2028, 2, 1), calendar: utc)
    #expect(moved == at(2028, 2, 29))
}

// MARK: - Band height

@Test func bandHeightIsOneRowForEmptyAndSingleDay() {
    let m = BandMetrics(scale: 1)
    #expect(m.height(forRows: 0) == m.height(forRows: 1))
}

@Test func bandHeightGrowsUpToFourRowsThenAddsPeek() {
    let m = BandMetrics(scale: 1)
    let four = m.height(forRows: 4)
    let five = m.height(forRows: 5)
    let nine = m.height(forRows: 9)
    #expect(m.height(forRows: 1) < four)
    #expect(five > four)
    #expect(five == nine)
    #expect(five - four == m.rowSpacing + m.peekHeight)
}

@Test func bandHeightScalesLinearly() {
    #expect(BandMetrics(scale: 2).height(forRows: 3) == BandMetrics(scale: 1).height(forRows: 3) * 2)
}

@Test func bandHeightMatchesLayoutSum() {
    let m = BandMetrics(scale: 1)
    let expected = m.topPadding + m.headerHeight + m.headerGap + m.bottomPadding
        + 4 * m.rowHeight + 3 * m.rowSpacing
    #expect(m.height(forRows: 4) == expected)
}

// MARK: - Open in Calendar.app

@Test func calendarAppURLPointsAtTheOccurrence() {
    var e = event("Standup", start: at(2026, 9, 15, 9, 30), end: at(2026, 9, 15, 10))
    e.eventIdentifier = "ABC-123"
    e.occurrence = at(2026, 9, 15, 9, 30)
    #expect(e.calendarAppURL?.absoluteString == "ical://ekevent/20260915T093000Z/ABC-123?method=show&options=more")
}

@Test func calendarAppURLIsNilWithoutAnIdentifier() {
    let e = event("Ghost", start: at(2026, 9, 15, 9), end: at(2026, 9, 15, 10))
    #expect(e.calendarAppURL == nil)
}

// MARK: - Initial scroll anchor

private let morning = event("Morning", start: at(2026, 9, 15, 9), end: at(2026, 9, 15, 10))
private let dentist = event("Dentist", start: at(2026, 9, 15, 14), end: at(2026, 9, 15, 15))
private let sync = event("Sync", start: at(2026, 9, 15, 16), end: at(2026, 9, 15, 17))
private let dinner = event("Dinner", start: at(2026, 9, 15, 19, 30), end: at(2026, 9, 15, 21))
private let todaysEvents = [morning, dentist, sync, dinner]

@Test func anchorIsFirstEventStillAhead() {
    let anchor = EventSchedule.initialAnchor(in: todaysEvents, now: at(2026, 9, 15, 15, 30), isToday: true)
    #expect(anchor == sync.id)
}

@Test func anchorKeepsAnEventInProgress() {
    let anchor = EventSchedule.initialAnchor(in: todaysEvents, now: at(2026, 9, 15, 14, 30), isToday: true)
    #expect(anchor == dentist.id)
}

@Test func anchorFallsBackToLastEventWhenAllArePast() {
    let anchor = EventSchedule.initialAnchor(in: todaysEvents, now: at(2026, 9, 15, 23), isToday: true)
    #expect(anchor == dinner.id)
}

@Test func anchorSkipsAllDayEventsWhenTimedOnesRemain() {
    let allDay = event("Offsite", start: at(2026, 9, 15), end: at(2026, 9, 15, 23, 59, 59), allDay: true)
    let anchor = EventSchedule.initialAnchor(in: [allDay] + todaysEvents, now: at(2026, 9, 15, 15, 30), isToday: true)
    #expect(anchor == sync.id)
}

@Test func anchorIsNilForOtherDaysAndEmptyLists() {
    #expect(EventSchedule.initialAnchor(in: todaysEvents, now: at(2026, 9, 15, 15, 30), isToday: false) == nil)
    #expect(EventSchedule.initialAnchor(in: [], now: at(2026, 9, 15, 15, 30), isToday: true) == nil)
}

// MARK: - Cache merge

private let sep29 = event("Sep 29", start: at(2026, 9, 29, 9), end: at(2026, 9, 29, 10))
private let oct5 = event("Oct 5", start: at(2026, 10, 5, 9), end: at(2026, 10, 5, 10))
private let oct20 = event("Oct 20", start: at(2026, 10, 20, 9), end: at(2026, 10, 20, 10))

@Test func mergeReplacesOnlyDaysInsideTheFetchedWindow() {
    let cache = EventSchedule.group([sep29, oct5], calendar: utc)
    let fetched = EventSchedule.group([oct20], calendar: utc)  // October window: Oct 5 is now gone
    let merged = EventSchedule.merge(cache, with: fetched, window: at(2026, 10, 1)..<at(2026, 11, 1), calendar: utc)
    #expect(merged[at(2026, 9, 29)] == [sep29])
    #expect(merged[at(2026, 10, 5)] == nil)
    #expect(merged[at(2026, 10, 20)] == [oct20])
}

@Test func mergeIgnoresPartialDaysOutsideTheWindow() {
    // A multi-day event that starts before the window would otherwise
    // overwrite Sep 29's full data with a single partial entry.
    let spanning = event("Offsite", start: at(2026, 9, 28), end: at(2026, 10, 2, 23, 59, 59), allDay: true)
    let cache = EventSchedule.group([sep29], calendar: utc)
    let fetched = EventSchedule.group([spanning], calendar: utc)
    let merged = EventSchedule.merge(cache, with: fetched, window: at(2026, 10, 1)..<at(2026, 11, 1), calendar: utc)
    #expect(merged[at(2026, 9, 29)] == [sep29])
    #expect(merged[at(2026, 9, 28)] == nil)
    #expect(merged[at(2026, 10, 1)] == [spanning])
    #expect(merged[at(2026, 10, 2)] == [spanning])
}

// MARK: - Local time zone sanity

@Test func selectionFollowsInAPositiveOffsetTimeZone() {
    var dhaka = Calendar(identifier: .gregorian)
    dhaka.timeZone = TimeZone(identifier: "Asia/Dhaka")!
    let sep15 = dhaka.date(from: DateComponents(year: 2026, month: 9, day: 15))!
    let oct1 = dhaka.date(from: DateComponents(year: 2026, month: 10, day: 1))!
    let moved = EventSchedule.followSelection(sep15, intoMonth: oct1, calendar: dhaka)
    #expect(dhaka.dateComponents([.year, .month, .day], from: moved) == DateComponents(year: 2026, month: 10, day: 15))
}
