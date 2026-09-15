import AppKit
import SwiftUI

/// The events band under the grid: the selected day's header, then one row
/// per event. Up to `BandMetrics.maxVisibleRows` rows are visible; more
/// scroll inside the band, with the next row peeking through as the hint.
/// Today's list starts at the first event still ahead; other days at the top.
/// Clicking a row opens the event in Calendar.app.
struct EventListView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let metrics: BandMetrics

    private var events: [EventItem] { viewModel.selectedEvents }

    private var anchor: EventItem.ID? {
        EventSchedule.initialAnchor(
            in: events, now: Date(),
            isToday: Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: viewModel.today)
        )
    }

    var body: some View {
        VStack(spacing: metrics.headerGap) {
            header
            if events.isEmpty {
                Text("No events")
                    .font(.system(size: metrics.emptyFontSize, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.rowHeight)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: metrics.rowSpacing) {
                            ForEach(events) { event in
                                EventRow(event: event, metrics: metrics)
                                    .id(event.id)
                            }
                        }
                    }
                    .onAppear { scroll(proxy, to: anchor) }
                    // Events arrive asynchronously after the day is shown.
                    .onChange(of: anchor) { _, id in scroll(proxy, to: id) }
                }
                .frame(height: metrics.rowsHeight(forRows: events.count))
                .clipped()
            }
        }
        .padding(.top, metrics.topPadding)
        .padding(.bottom, metrics.bottomPadding)
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
        }
        // Rebuild the list per day so its scroll position resets and the
        // anchor logic runs again in onAppear.
        .id(viewModel.selectedDate)
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: EventItem.ID?) {
        guard let id, events.count > BandMetrics.maxVisibleRows else { return }
        proxy.scrollTo(id, anchor: .top)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Self.dayFormatter.string(from: viewModel.selectedDate))
                .font(.system(size: metrics.dateFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer(minLength: metrics.columnGap)
            Text(countLabel)
                .font(.system(size: metrics.countFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .frame(height: metrics.headerHeight)
    }

    private var countLabel: String {
        switch events.count {
        case 0: return ""
        case 1: return "1 event"
        default: return "\(events.count) events"
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter
    }()
}

struct EventRow: View {
    let event: EventItem
    let metrics: BandMetrics

    @State private var hovering = false

    var body: some View {
        HStack(spacing: metrics.columnGap) {
            RoundedRectangle(cornerRadius: metrics.barWidth / 2, style: .continuous)
                .fill(event.color.color)
                .frame(width: metrics.barWidth, height: metrics.barHeight)

            timeColumn
                .frame(width: metrics.timeColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: metrics.titleFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(event.calendarTitle)
                    .font(.system(size: metrics.calendarFontSize, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.columnGap * 0.6)
        .frame(height: metrics.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: metrics.rowHeight * 0.2, style: .continuous)
                .fill(Color.primary.opacity(hovering && event.calendarAppURL != nil ? 0.06 : 0))
        )
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { openInCalendar() }
        .help(event.calendarAppURL == nil ? event.title : "Open in Calendar")
    }

    private func openInCalendar() {
        guard let url = event.calendarAppURL else { return }
        NSWorkspace.shared.open(url)
    }

    @ViewBuilder
    private var timeColumn: some View {
        if event.isAllDay {
            Text("ALL DAY")
                .font(.system(size: metrics.allDayFontSize, weight: .semibold, design: .rounded))
                .tracking(0.3)
                .foregroundStyle(.tertiary)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(Self.timeFormatter.string(from: event.start))
                    .font(.system(size: metrics.timeFontSize, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(Self.timeFormatter.string(from: event.end))
                    .font(.system(size: metrics.endTimeFontSize, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
