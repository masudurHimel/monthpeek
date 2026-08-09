import Foundation
import Testing

@testable import MonthPeek

private func makeCalendar(firstWeekday: Int) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.locale = Locale(identifier: "en_US")
    calendar.firstWeekday = firstWeekday
    return calendar
}

private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

@Test func gridIsAlwaysSixWeeksOfSevenDays() {
    let calendar = makeCalendar(firstWeekday: 1)
    let weeks = MonthGrid.weeks(for: date(2026, 8, 1, calendar: calendar), calendar: calendar)
    #expect(weeks.count == 6)
    #expect(weeks.allSatisfy { $0.days.count == 7 })
}

@Test(arguments: [1, 2])
func firstCellMatchesFirstWeekday(firstWeekday: Int) {
    let calendar = makeCalendar(firstWeekday: firstWeekday)
    let weeks = MonthGrid.weeks(for: date(2026, 8, 1, calendar: calendar), calendar: calendar)
    #expect(calendar.component(.weekday, from: weeks[0].days[0].date) == firstWeekday)
}

@Test func containsEveryDayOfDisplayedMonth() {
    let calendar = makeCalendar(firstWeekday: 2)
    let weeks = MonthGrid.weeks(for: date(2026, 8, 1, calendar: calendar), calendar: calendar)
    let inMonth = weeks.flatMap(\.days).filter(\.isInDisplayedMonth)
    #expect(inMonth.count == 31)
    #expect(inMonth.first?.dayNumber == 1)
    #expect(inMonth.last?.dayNumber == 31)
}

@Test func adjacentMonthDaysPadTheGrid() {
    // August 2026 starts on a Saturday; with a Sunday week start the first
    // row begins on July 26.
    let calendar = makeCalendar(firstWeekday: 1)
    let weeks = MonthGrid.weeks(for: date(2026, 8, 1, calendar: calendar), calendar: calendar)
    #expect(weeks[0].days[0].date == date(2026, 7, 26, calendar: calendar))
    #expect(!weeks[0].days[0].isInDisplayedMonth)
}

@Test func weekendFlag() {
    let calendar = makeCalendar(firstWeekday: 1)
    let weeks = MonthGrid.weeks(for: date(2026, 8, 1, calendar: calendar), calendar: calendar)
    let days = weeks.flatMap(\.days)
    // 2026-08-08 is a Saturday, 2026-08-10 is a Monday.
    #expect(days.first { $0.date == date(2026, 8, 8, calendar: calendar) }!.isWeekend)
    #expect(!days.first { $0.date == date(2026, 8, 10, calendar: calendar) }!.isWeekend)
}

@Test func weekdaySymbolsRotateWithFirstWeekday() {
    #expect(MonthGrid.weekdaySymbols(calendar: makeCalendar(firstWeekday: 1)).first == "Su")
    #expect(MonthGrid.weekdaySymbols(calendar: makeCalendar(firstWeekday: 2)).first == "Mo")
}
