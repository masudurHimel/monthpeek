import Foundation
import SwiftUI

/// An RGBA color as plain doubles so event data can cross threads and stay
/// free of EventKit and AppKit types. Built from the calendar's `cgColor`.
struct EventColor: Equatable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(cgColor: CGColor?) {
        guard
            let cgColor,
            let rgb = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
            let c = rgb.components, c.count >= 3
        else {
            self.init(red: 0.56, green: 0.56, blue: 0.58)
            return
        }
        self.init(red: c[0], green: c[1], blue: c[2], alpha: c.count > 3 ? c[3] : 1)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
}

/// One calendar as shown in the Preferences checklist.
struct CalendarInfo: Identifiable, Equatable, Sendable {
    enum Kind: Sendable { case regular, shared, subscribed, birthday }

    let id: String
    let title: String
    let sourceTitle: String
    let color: EventColor
    let kind: Kind
}

/// One event occurrence, detached from EventKit.
struct EventItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarID: String
    let calendarTitle: String
    let color: EventColor
    /// EventKit's local `calendarItemIdentifier` (a UUID shared by every
    /// occurrence of a recurring event). Empty when unavailable.
    var eventIdentifier: String = ""
    /// Start of this particular occurrence, for the Calendar.app deep link.
    var occurrence: Date? = nil

    /// Deep link Calendar.app understands (the same form it uses in its own
    /// notifications): `ical://ekevent/<occurrence UTC>/<calendarItemIdentifier>?method=show&options=more`.
    /// Verified on macOS 15: EventKit's `eventIdentifier` ("<calendar>:<uid>")
    /// only opens Calendar; the local calendar-item UUID jumps to the event.
    var calendarAppURL: URL? {
        guard !eventIdentifier.isEmpty,
              let identifier = eventIdentifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        let stamp = Self.occurrenceFormatter.string(from: occurrence ?? start)
        return URL(string: "ical://ekevent/\(stamp)/\(identifier)?method=show&options=more")
    }

    private static let occurrenceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()
}

