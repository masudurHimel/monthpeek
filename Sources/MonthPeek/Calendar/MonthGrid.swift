import Foundation

/// Pure date math for one month page: always 6 rows × 7 columns, padded
/// with adjacent-month days, honoring the calendar's firstWeekday.
enum MonthGrid {
    struct Day: Identifiable, Equatable {
        let date: Date
        let dayNumber: Int
        let isInDisplayedMonth: Bool
        let isWeekend: Bool

        var id: Date { date }
    }

    struct Week: Identifiable {
        let weekNumber: Int
        let days: [Day]

        var id: Date { days[0].date }
    }

    static func weeks(for month: Date, calendar: Calendar) -> [Week] {
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let weekdayOfFirst = calendar.component(.weekday, from: first)
        let offset = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -offset, to: first)!
        let displayedMonth = calendar.component(.month, from: first)

        return (0..<6).map { weekIndex in
            let days = (0..<7).map { dayIndex -> Day in
                let date = calendar.date(byAdding: .day, value: weekIndex * 7 + dayIndex, to: gridStart)!
                return Day(
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    isInDisplayedMonth: calendar.component(.month, from: date) == displayedMonth,
                    isWeekend: calendar.isDateInWeekend(date)
                )
            }
            return Week(
                weekNumber: calendar.component(.weekOfYear, from: days[0].date),
                days: days
            )
        }
    }

    /// Two-letter weekday symbols rotated so the calendar's firstWeekday
    /// comes first (e.g. "Su Mo … Sa" or "Mo Tu … Su").
    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols.map { String($0.prefix(2)) }
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
