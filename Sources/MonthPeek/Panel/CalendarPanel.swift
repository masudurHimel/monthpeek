import AppKit

/// The floating calendar card. A non-activating panel so it can appear above
/// every app — including fullscreen ones — without stealing focus from
/// whatever the user is working in.
final class CalendarPanel: NSPanel {
    var onEscape: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        animationBehavior = .none  // PanelController animates show/hide itself

        minSize = NSSize(width: 240, height: 260)
        maxSize = NSSize(width: 600, height: 640)
    }

    // Key status lets the panel receive Esc and scroll events without
    // activating the app (guaranteed by .nonactivatingPanel).
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // Esc
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}
