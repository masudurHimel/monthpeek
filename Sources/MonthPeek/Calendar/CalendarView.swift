import AppKit
import SwiftUI

/// Root of the panel's SwiftUI hierarchy: translucent material card with
/// the calendar on top.
struct PanelRootView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        ZStack {
            VisualEffectView()
            CalendarView(viewModel: viewModel)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        // Pop out of the menu bar downward on open, retract up into it on
        // close. Animating the card (not the window) keeps this reliable.
        .scaleEffect(viewModel.isPresented ? 1 : 0.55, anchor: .top)
        .offset(y: viewModel.isPresented ? 0 : -18)
        .opacity(viewModel.isPresented ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: viewModel.isPresented)
        .ignoresSafeArea()
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Month/year header, weekday row, and the 6×7 day grid. Everything is
/// sized from the panel's current dimensions so the layout scales fluidly
/// as the user resizes.
struct CalendarView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @AppStorage(SettingsKey.weekStart) private var weekStartRaw = WeekStart.sunday.rawValue
    @AppStorage(SettingsKey.showWeekNumbers) private var showWeekNumbers = false

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = (WeekStart(rawValue: weekStartRaw) ?? .sunday).firstWeekday
        return calendar
    }

    var body: some View {
        GeometryReader { geo in
            let m = Metrics(size: geo.size, showWeekNumbers: showWeekNumbers)
            VStack(spacing: m.sectionSpacing) {
                header(m)
                weekdayRow(m)
                monthGrid(m)
            }
            .padding(.horizontal, m.outerPadding)
            .padding(.top, m.outerPadding * 0.55)
            .padding(.bottom, m.outerPadding * 0.8)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Header

    private func header(_ m: Metrics) -> some View {
        HStack(spacing: 0) {
            Button(action: viewModel.goToToday) {
                Text(Self.titleFormatter.string(from: viewModel.displayedMonth))
                    .font(.system(size: m.headerFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: viewModel.displayedMonth)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Jump to today")

            Spacer(minLength: m.sectionSpacing)

            HStack(spacing: m.sectionSpacing * 0.75) {
                navButton(symbol: "chevron.left", size: m, action: viewModel.previousMonth)
                navButton(symbol: "chevron.right", size: m, action: viewModel.nextMonth)
            }
        }
    }

    private func navButton(symbol: String, size m: Metrics, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: m.chevronFontSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: m.chevronFontSize * 2, height: m.chevronFontSize * 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverCircleButtonStyle())
    }

    // MARK: - Weekday row

    private func weekdayRow(_ m: Metrics) -> some View {
        HStack(spacing: 0) {
            if showWeekNumbers {
                Color.clear.frame(width: m.gutterWidth, height: 1)
            }
            ForEach(MonthGrid.weekdaySymbols(calendar: calendar), id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: m.weekdayFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day grid

    private func monthGrid(_ m: Metrics) -> some View {
        GeometryReader { geo in
            let weeks = MonthGrid.weeks(for: viewModel.displayedMonth, calendar: calendar)
            let cellWidth = (geo.size.width - m.gutterWidth) / 7
            let cellHeight = geo.size.height / 6
            let circleSize = min(cellWidth, cellHeight) * 0.82

            ZStack {
                VStack(spacing: 0) {
                    ForEach(weeks) { week in
                        HStack(spacing: 0) {
                            if showWeekNumbers {
                                Text("\(week.weekNumber)")
                                    .font(.system(size: m.weekNumberFontSize, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.quaternary)
                                    .frame(width: m.gutterWidth)
                            }
                            ForEach(week.days) { day in
                                DayCell(
                                    day: day,
                                    isToday: calendar.isDate(day.date, inSameDayAs: viewModel.today),
                                    circleSize: circleSize,
                                    fontSize: m.dayFontSize
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
                .id(viewModel.displayedMonth)
                .transition(monthTransition)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // Explicit value-bound animation: withAnimation alone can fail to
            // drive transitions inside NSHostingView.
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.displayedMonth)
        }
        .clipped()
    }

    private var monthTransition: AnyTransition {
        switch viewModel.direction {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .none:
            return .opacity
        }
    }

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter
    }()
}

/// One day number, with the today highlight and a soft hover circle.
struct DayCell: View {
    let day: MonthGrid.Day
    let isToday: Bool
    let circleSize: CGFloat
    let fontSize: CGFloat

    @State private var hovering = false

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: circleSize, height: circleSize)
            } else {
                Circle()
                    .fill(Color.primary.opacity(0.09))
                    .frame(width: circleSize, height: circleSize)
                    .scaleEffect(hovering ? 1 : 0.6)
                    .opacity(hovering ? 1 : 0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovering)
            }
            Text("\(day.dayNumber)")
                .font(.system(size: fontSize, weight: isToday ? .semibold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textColor)
        }
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
        }
    }

    private var textColor: Color {
        if isToday { return .white }
        if !day.isInDisplayedMonth { return Color.primary.opacity(0.25) }
        if day.isWeekend { return Color(nsColor: .secondaryLabelColor) }
        return .primary
    }
}

/// Plain button that shows a soft circle behind its label while hovered.
struct HoverCircleButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle().fill(Color.primary.opacity(
                    configuration.isPressed ? 0.14 : (hovering ? 0.08 : 0)
                ))
            )
            .onHover { inside in
                withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
            }
    }
}

/// All sizes derive from the panel width so typography and spacing scale
/// proportionally with the window.
private struct Metrics {
    let size: CGSize
    let showWeekNumbers: Bool

    var scale: CGFloat { max(0.8, min(2.2, size.width / 300)) }

    var outerPadding: CGFloat { 14 * scale }
    var sectionSpacing: CGFloat { 8 * scale }
    var headerFontSize: CGFloat { 15 * scale }
    var chevronFontSize: CGFloat { 11 * scale }
    var weekdayFontSize: CGFloat { 10 * scale }
    var dayFontSize: CGFloat { 12.5 * scale }
    var weekNumberFontSize: CGFloat { 9 * scale }
    var gutterWidth: CGFloat { showWeekNumbers ? 22 * scale : 0 }
}
