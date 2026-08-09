import AppKit
import SwiftUI

@main
enum MonthPeekMain {
    static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceMode.current.apply()
        statusItemController = StatusItemController()
    }
}
