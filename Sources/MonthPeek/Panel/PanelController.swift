import AppKit
import Combine
import SwiftUI

/// Shows, hides, and positions the floating calendar panel, persists its
/// size across launches, and closes it when the user clicks elsewhere
/// (unless the panel is pinned).
///
/// The saved size describes the *grid*. When the events feature is on, the
/// events band is added below it and the window frame grows and shrinks
/// with the selected day's row count, top edge anchored under the menu bar.
final class PanelController: NSObject, NSWindowDelegate {
    private static let minGridSize = NSSize(width: 240, height: 260)
    private static let maxGridSize = NSSize(width: 600, height: 640)

    private var panel: CalendarPanel?
    private let viewModel = CalendarViewModel()
    private var scrollMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var lastAutoClose: TimeInterval = 0
    private var isClosing = false
    /// Height currently added below the grid for the events band.
    private var bandHeight: CGFloat = 0

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
        EventStoreService.shared.requestAccessIfWanted()
        EventStoreService.shared.refreshSources()
        viewModel.resetToToday()
        viewModel.reloadEvents()
        updateBandHeight(animated: false)
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
        width = min(max(width, Self.minGridSize.width), Self.maxGridSize.width)
        height = min(max(height, Self.minGridSize.height), Self.maxGridSize.height)

        let newPanel = CalendarPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height))
        newPanel.delegate = self
        newPanel.onEscape = { [weak self] in self?.hide() }
        newPanel.contentView = NSHostingView(rootView: PanelRootView(viewModel: viewModel))
        panel = newPanel

        // Anything that changes the band's row count resizes the window.
        viewModel.$eventsEnabled.map { _ in () }
            .merge(with: viewModel.$selectedDate.map { _ in () })
            .merge(with: viewModel.$eventsByDay.map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                self.updateBandHeight(animated: self.isVisible && !self.isClosing)
            }
            .store(in: &cancellables)

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

    // MARK: - Events band sizing

    private func desiredBandHeight(forWidth width: CGFloat) -> CGFloat {
        guard viewModel.eventsEnabled else { return 0 }
        let metrics = BandMetrics(scale: BandMetrics.scale(forPanelWidth: width))
        return metrics.height(forRows: viewModel.selectedEvents.count)
    }

    /// Re-derive the band height from the view model and grow or shrink the
    /// window by the difference, keeping the top edge where it is.
    private func updateBandHeight(animated: Bool) {
        guard let panel else { return }
        let newBand = desiredBandHeight(forWidth: panel.frame.width)
        let delta = newBand - bandHeight
        guard abs(delta) > 0.5 else { return }
        bandHeight = newBand
        applySizeLimits(to: panel)

        var frame = panel.frame
        frame.size.height += delta
        frame.origin.y -= delta
        panel.setFrame(frame, display: true, animate: animated && panel.isVisible)
    }

    private func applySizeLimits(to panel: NSPanel) {
        panel.minSize = NSSize(width: Self.minGridSize.width, height: Self.minGridSize.height + bandHeight)
        panel.maxSize = NSSize(width: Self.maxGridSize.width, height: Self.maxGridSize.height + bandHeight)
    }

    // MARK: - Scroll wheel / trackpad month navigation

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let panel = self.panel, event.window === panel else { return event }
            // Only the grid flips months; over the events band the wheel
            // scrolls the list, so let the event through untouched.
            let contentHeight = panel.contentView?.bounds.height ?? panel.frame.height
            if event.locationInWindow.y >= self.bandHeight || contentHeight <= self.bandHeight {
                self.viewModel.handleScroll(event)
            }
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
        // The band's height depends on the width the user just chose, and
        // the SwiftUI layout already reflects that; store only the grid part.
        bandHeight = desiredBandHeight(forWidth: panel.frame.width)
        applySizeLimits(to: panel)
        UserDefaults.standard.set(Double(panel.frame.width), forKey: SettingsKey.panelWidth)
        UserDefaults.standard.set(Double(panel.frame.height - bandHeight), forKey: SettingsKey.panelHeight)
    }
}
