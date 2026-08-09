import ServiceManagement
import SwiftUI

struct PreferencesView: View {
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.weekStart) private var weekStartRaw = WeekStart.sunday.rawValue
    @AppStorage(SettingsKey.showWeekNumbers) private var showWeekNumbers = false
    @AppStorage(SettingsKey.pinPanel) private var pinPanel = false

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

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
        }
        .padding(20)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: appearanceRaw) { _, _ in
            AppearanceMode.current.apply()
        }
        .onChange(of: launchAtLogin) { _, enabled in
            setLaunchAtLogin(enabled)
        }
    }

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
