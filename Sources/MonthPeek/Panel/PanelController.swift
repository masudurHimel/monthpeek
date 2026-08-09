import AppKit
import SwiftUI

/// Shows, hides, and positions the floating calendar panel, persists its
/// size across launches, and closes it when the user clicks elsewhere
/// (unless the panel is pinned).
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: CalendarPanel?
    private let viewModel = CalendarViewModel()
    private var scrollMonitor: Any?
    private var lastAutoClose: TimeInterval = 0
    private var isClosing = false

    private var isPinned: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.pinPanel)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(relativeTo statusItem: NSStatusItem) {
        if isVisible && !isClosing {
            hide()
        } else {
            // The click that lands on the status item first closes the panel
            // via windowDidResignKey; without this guard, "click icon to
            // dismiss" would instantly reopen it.
            if ProcessInfo.processInfo.systemUptime - lastAutoClose < 0.25 { return }
            show(relativeTo: statusItem)
        }
    }

    func show(relativeTo statusItem: NSStatusItem) {
        let panel = ensurePanel()
        isClosing = false
        viewModel.resetToToday()
        position(panel, relativeTo: statusItem)

        panel.makeKeyAndOrderFront(nil)
        // Flip on the next runloop pass so the card's collapsed state is on
        // screen first and the change animates.
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.isPresented = true
        }
        installScrollMonitor()
    }

    func hide() {
        removeScrollMonitor()
        guard let panel, panel.isVisible, !isClosing else { return }
        isClosing = true
        viewModel.isPresented = false
        // Order the window out only after the retract animation has played.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            guard let self, self.isClosing else { return }
            self.isClosing = false
            panel.orderOut(nil)
        }
    }

    func hideUnlessPinned() {
        if isVisible && !isPinned { hide() }
    }

    func dayChanged() {
        viewModel.dayChanged()
    }

    private func ensurePanel() -> CalendarPanel {
        if let panel { return panel }

        let defaults = UserDefaults.standard
        var width = defaults.double(forKey: SettingsKey.panelWidth)
        var height = defaults.double(forKey: SettingsKey.panelHeight)
        if width == 0 { width = 300 }
        if height == 0 { height = 324 }
        width = min(max(width, 240), 600)
        height = min(max(height, 260), 640)

        let newPanel = CalendarPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height))
        newPanel.delegate = self
        newPanel.onEscape = { [weak self] in self?.hide() }
        newPanel.contentView = NSHostingView(rootView: PanelRootView(viewModel: viewModel))
        panel = newPanel
        return newPanel
    }

    private func position(_ panel: NSPanel, relativeTo statusItem: NSStatusItem) {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size

        var x = buttonRect.midX - size.width / 2
        let y = buttonRect.minY - size.height - 6
        if let screen = buttonWindow.screen {
            x = min(max(x, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
        }
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    // MARK: - Scroll wheel / trackpad month navigation

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            self.viewModel.handleScroll(event)
            return event
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        guard isVisible, !isPinned else { return }
        lastAutoClose = ProcessInfo.processInfo.systemUptime
        hide()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel else { return }
        UserDefaults.standard.set(Double(panel.frame.width), forKey: SettingsKey.panelWidth)
        UserDefaults.standard.set(Double(panel.frame.height), forKey: SettingsKey.panelHeight)
    }
}
