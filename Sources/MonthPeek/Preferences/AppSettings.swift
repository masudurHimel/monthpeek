import AppKit

enum SettingsKey {
    static let appearance = "appearanceMode"
    static let weekStart = "weekStartsOn"
    static let showWeekNumbers = "showWeekNumbers"
    static let pinPanel = "pinPanel"
    static let panelWidth = "panelWidth"
    static let panelHeight = "panelHeight"
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    static var current: AppearanceMode {
        AppearanceMode(rawValue: UserDefaults.standard.string(forKey: SettingsKey.appearance) ?? "") ?? .system
    }

    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum WeekStart: String, CaseIterable, Identifiable {
    case sunday, monday

    var id: String { rawValue }

    /// 1 = Sunday, 2 = Monday (Calendar.firstWeekday convention).
    var firstWeekday: Int { self == .sunday ? 1 : 2 }

    var label: String { self == .sunday ? "Sunday" : "Monday" }

    static var current: WeekStart {
        WeekStart(rawValue: UserDefaults.standard.string(forKey: SettingsKey.weekStart) ?? "") ?? .sunday
    }
}
