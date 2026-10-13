import AppKit
import SwiftUI

/// Root of the panel's SwiftUI hierarchy: translucent material card with
/// the calendar on top and, when the events feature is on, the events band
/// beneath it. The band's height comes from `BandMetrics`, the same formula
/// the PanelController uses to size the window, so the grid always keeps
/// the height the user saved.
struct PanelRootView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        ZStack {
            VisualEffectView()
            GeometryReader { geo in
                let band = BandMetrics(scale: BandMetrics.scale(forPanelWidth: geo.size.width))
                let bandHeight = viewModel.eventsEnabled
                    ? band.height(forRows: viewModel.selectedEvents.count) : 0
                VStack(spacing: 0) {
                    CalendarView(viewModel: viewModel)
                        .frame(height: max(0, geo.size.height - bandHeight))
                    EventListView(viewModel: viewModel, metrics: band)
                        .frame(height: bandHeight)
                        .clipped()
                        .opacity(viewModel.eventsEnabled ? 1 : 0)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                // Grow/shrink the band in step with the window frame (same
                // 0.3s ease) so the grid above holds still instead of
                // squeezing. Keyed off the toggle and the row count — not the
                // height — so live-resizing the panel (which also moves the
                // band height via the width-based scale) stays responsive.
                .animation(.easeInOut(duration: 0.3), value: viewModel.eventsEnabled)
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedEvents.count)
            }
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
    @AppStorage(SettingsKey.showEvents) private var showEvents = false

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

            eventsToggle(m)
                .padding(.leading, m.sectionSpacing * 0.5)

            Spacer(minLength: m.sectionSpacing)

            HStack(spacing: m.sectionSpacing * 0.75) {
                navButton(symbol: "chevron.left", size: m, action: viewModel.previousMonth)
                navButton(symbol: "chevron.right", size: m, action: viewModel.nextMonth)
            }
        }
    }

    /// Small toggle beside the month title that turns the events band on and
    /// off, mirroring the "Show calendar events" switch in Preferences — it
    /// writes the same setting and, the first time it is turned on, triggers
    /// the macOS Calendars prompt. Lit in the accent color while the band is
    /// actually showing (toggle on *and* access granted).
    private func eventsToggle(_ m: Metrics) -> some View {
        Button(action: toggleEvents) {
            Image(systemName: "list.bullet")
                .font(.system(size: m.chevronFontSize, weight: .semibold))
                .foregroundStyle(viewModel.eventsEnabled ? Color.accentColor : Color.secondary)
                .frame(width: m.chevronFontSize * 2, height: m.chevronFontSize * 2)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.15), value: viewModel.eventsEnabled)
        }
        .buttonStyle(HoverCircleButtonStyle())
        .help(viewModel.eventsEnabled ? "Hide calendar events" : "Show calendar events")
    }

    /// Flip the setting the same way Preferences does: turning it on asks for
    /// calendar access if needed and springs back off when access is refused.
    private func toggleEvents() {
        if showEvents {
            showEvents = false
        } else {
            showEvents = true
            let events = EventStoreService.shared
            if !events.hasFullAccess {
                Task { @MainActor in
                    if await !events.requestAccess() { showEvents = false }
                }
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
                                    isSelected: viewModel.eventsEnabled
                                        && calendar.isDate(day.date, inSameDayAs: viewModel.selectedDate),
                                    dot: dotStyle(for: day),
                                    circleSize: circleSize,
                                    fontSize: m.dayFontSize
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.select(day.date) }
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

    private func dotStyle(for day: MonthGrid.Day) -> EventSchedule.DotStyle {
        guard viewModel.eventsEnabled, viewModel.showDots else { return .none }
        return EventSchedule.dotStyle(for: viewModel.eventsByDay[calendar.startOfDay(for: day.date)] ?? [])
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

/// One day number, with the today highlight, the selection ring, an
/// optional event dot, and a soft hover circle.
struct DayCell: View {
    let day: MonthGrid.Day
    let isToday: Bool
    var isSelected = false
    var dot: EventSchedule.DotStyle = .none
    let circleSize: CGFloat
    let fontSize: CGFloat

    @State private var hovering = false

    var body: some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: circleSize, height: circleSize)
            } else if isSelected {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 1.5))
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
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(day.isInDisplayedMonth ? 1 : 0.35)
                    .offset(y: circleSize / 2 - dotSize - 3 * (circleSize / 32))
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
        }
    }

    private var dotSize: CGFloat { max(3, circleSize / 8) }

    private var dotColor: Color? {
        switch dot {
        case .none: return nil
        case .calendar(let color): return isToday ? .white.opacity(0.9) : color.color
        case .mixed: return isToday ? .white.opacity(0.9) : Color(nsColor: .systemGray)
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

    var scale: CGFloat { BandMetrics.scale(forPanelWidth: size.width) }

    var outerPadding: CGFloat { 14 * scale }
    var sectionSpacing: CGFloat { 8 * scale }
    var headerFontSize: CGFloat { 15 * scale }
    var chevronFontSize: CGFloat { 11 * scale }
    var weekdayFontSize: CGFloat { 10 * scale }
    var dayFontSize: CGFloat { 12.5 * scale }
    var weekNumberFontSize: CGFloat { 9 * scale }
    var gutterWidth: CGFloat { showWeekNumbers ? 22 * scale : 0 }
}
