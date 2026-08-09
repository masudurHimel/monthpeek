import AppKit

/// Owns the menu bar status item. Left-click toggles the calendar panel;
/// right-click (or ctrl-click) shows the two-item context menu. The menu is
/// assigned to the status item only for the duration of the click — a
/// permanently assigned menu would hijack left-click as well.
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let panelController = PanelController()
    private let preferencesWindow = PreferencesWindowController()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = Self.calendarIcon(day: Calendar.current.component(.day, from: Date()))
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(dayChanged),
            name: .NSCalendarDayChanged, object: nil
        )
    }

    @objc private func dayChanged() {
        DispatchQueue.main.async { [self] in
            statusItem.button?.image = Self.calendarIcon(day: Calendar.current.component(.day, from: Date()))
            panelController.dayChanged()
        }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isRightClick {
            showContextMenu()
        } else {
            panelController.toggle(relativeTo: statusItem)
        }
    }

    private func showContextMenu() {
        panelController.hideUnlessPinned()

        let menu = NSMenu()
        let preferences = NSMenuItem(
            title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","
        )
        preferences.target = self
        menu.addItem(preferences)
        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPreferences() {
        preferencesWindow.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// Draws a small template calendar glyph with today's date number inside,
    /// like the system Calendar app icon in miniature.
    private static func calendarIcon(day: Int) -> NSImage {
        let size = NSSize(width: 18, height: 15)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 0.6, dy: 0.6)
            let radius: CGFloat = 3.5
            let headerHeight: CGFloat = 4.4

            let outline = NSBezierPath(roundedRect: inset, xRadius: radius, yRadius: radius)
            outline.lineWidth = 1.2
            NSColor.black.setStroke()
            outline.stroke()

            NSGraphicsContext.current?.saveGraphicsState()
            NSBezierPath(roundedRect: inset, xRadius: radius, yRadius: radius).addClip()
            NSColor.black.setFill()
            NSRect(x: 0, y: rect.height - headerHeight - 0.6, width: rect.width, height: headerHeight + 0.6)
                .fill()
            NSGraphicsContext.current?.restoreGraphicsState()

            let font = NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .bold)
            let text = NSAttributedString(
                string: String(day),
                attributes: [.font: font, .foregroundColor: NSColor.black]
            )
            let textSize = text.size()
            let bodyHeight = rect.height - headerHeight - 0.6
            text.draw(at: NSPoint(
                x: (rect.width - textSize.width) / 2,
                y: (bodyHeight - textSize.height) / 2 + 0.3
            ))
            return true
        }
        image.isTemplate = true
        return image
    }
}
