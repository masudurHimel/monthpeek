import AppKit
import SwiftUI

/// Standard titled, closable preferences window. Created lazily, kept
/// alive across closes, and restores its last position via frame autosave.
final class PreferencesWindowController: NSObject {
    private var window: NSWindow?

    func show() {
        let window = ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "MonthPeek Preferences"
        newWindow.isReleasedWhenClosed = false

        // The calendar checklist comes and goes with the events toggle, so
        // the view reports its size and the window follows it explicitly.
        // (NSHostingView's preferredContentSize option collapses this
        // non-resizable window to 0×0 instead.)
        let hosting = NSHostingView(rootView: PreferencesView(onSizeChange: { [weak self] size in
            self?.fit(to: size)
        }))
        newWindow.contentView = hosting
        newWindow.setContentSize(hosting.fittingSize)

        newWindow.center()
        newWindow.setFrameAutosaveName("MonthPeekPreferences")

        window = newWindow
        return newWindow
    }

    /// Resize the window to the content's new size, keeping the top-left
    /// corner in place so the title bar does not jump.
    private func fit(to size: CGSize) {
        guard let window, size.width > 0, size.height > 0 else { return }
        let current = window.contentRect(forFrameRect: window.frame).size
        guard abs(current.height - size.height) > 0.5 || abs(current.width - size.width) > 0.5 else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}
