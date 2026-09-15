import ServiceManagement
import SwiftUI

struct PreferencesView: View {
    /// Called with the content's laid-out size so the window can follow it.
    var onSizeChange: ((CGSize) -> Void)? = nil

    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.weekStart) private var weekStartRaw = WeekStart.sunday.rawValue
    @AppStorage(SettingsKey.showWeekNumbers) private var showWeekNumbers = false
    @AppStorage(SettingsKey.pinPanel) private var pinPanel = false
    @AppStorage(SettingsKey.showEvents) private var showEvents = false
    @AppStorage(SettingsKey.showEventDots) private var showEventDots = false

    @ObservedObject private var events = EventStoreService.shared
    @State private var hiddenCalendars = HiddenCalendars.current

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    /// The toggle is on and access is granted: the band is actually shown.
    private var eventsActive: Bool { showEvents && events.hasFullAccess }

    var body: some View {
        Form {
            Picker("Appearance:", selection: $appearanceRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }

            Picker("Week starts on:", selection: $weekStartRaw) {
                ForEach(WeekStart.allCases) { start in
                    Text(start.label).tag(start.rawValue)
                }
            }

            Toggle("Show week numbers", isOn: $showWeekNumbers)

            Toggle("Pin panel", isOn: $pinPanel)
            Text("Keep the calendar open when clicking elsewhere.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Launch at login", isOn: $launchAtLogin)
            if let launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Toggle("Show calendar events", isOn: $showEvents)
            eventsCaption

            Toggle("Show event dots in the grid", isOn: $showEventDots)
                .disabled(!eventsActive)
            Text("Marks days that have events.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(eventsActive ? 1 : 0.5)

            if eventsActive {
                calendarList
            }
        }
        .padding(20)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { onSizeChange?(geo.size) }
                    .onChange(of: geo.size) { _, size in onSizeChange?(size) }
            }
        )
        .onChange(of: appearanceRaw) { _, _ in
            AppearanceMode.current.apply()
        }
        .onChange(of: launchAtLogin) { _, enabled in
            setLaunchAtLogin(enabled)
        }
        .onChange(of: showEvents) { _, enabled in
            setShowEvents(enabled)
        }
        .onAppear {
            events.requestAccessIfWanted()
        }
    }

    // MARK: - Events

    @ViewBuilder
    private var eventsCaption: some View {
        if events.isBlocked {
            (Text("Calendar access is off for MonthPeek. Allow it in ")
                + Text("System Settings › Privacy & Security › Calendars").foregroundStyle(Color.accentColor)
                + Text(", then turn this on again."))
                .font(.caption)
                .foregroundStyle(.red)
                .onTapGesture { EventStoreService.openPrivacySettings() }
        } else {
            Text("Lists the selected day's events under the grid. Read-only. While this is off, MonthPeek never asks for calendar access.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Turning the toggle on is the only place MonthPeek asks for calendar
    /// access. If access is not granted the toggle springs back off; the
    /// caption (driven by the service's status) explains how to fix it.
    private func setShowEvents(_ enabled: Bool) {
        guard enabled, !events.hasFullAccess else { return }
        Task { @MainActor in
            if await !events.requestAccess() {
                showEvents = false
            }
        }
    }

    private var calendarList: some View {
        let groups = Dictionary(grouping: events.calendars, by: \.sourceTitle)
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(groups, id: \.key) { source, calendars in
                Text(source.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                ForEach(calendars) { calendar in
                    Toggle(isOn: isShownBinding(for: calendar.id)) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(calendar.color.color)
                                .frame(width: 9, height: 9)
                            Text(calendar.title)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            if let tag = tag(for: calendar.kind) {
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private func isShownBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { !hiddenCalendars.contains(id) },
            set: { shown in
                if shown { hiddenCalendars.remove(id) } else { hiddenCalendars.insert(id) }
                HiddenCalendars.set(hiddenCalendars)
            }
        )
    }

    private func tag(for kind: CalendarInfo.Kind) -> String? {
        switch kind {
        case .subscribed: return "Subscribed"
        case .birthday: return "Birthdays"
        case .shared: return "Shared"
        case .regular: return nil
        }
    }

    // MARK: - Launch at login

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        guard enabled != (service.status == .enabled) else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLogin = service.status == .enabled
            launchAtLoginError = error.localizedDescription
        }
    }
}
