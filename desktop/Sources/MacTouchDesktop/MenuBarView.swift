import SwiftUI
import MacTouchCore

/// The menu-bar menu: state at a glance and the few actions needed day to day.
struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.headline)
        Text(model.subheadline)
        Divider()

        Button("Pair a Phone\u{2026}") { show("pair") }
            .disabled(!model.isRunning)
        Button("Open MacTouch") { show("main") }
        Divider()

        if let device = model.connectedDevice {
            Button("Disconnect \(device.name)") { model.disconnectDevice() }
        }
        if model.isRunning {
            Button("Stop Server") { model.stopServer() }
        } else {
            Button("Start Server") { model.startServer() }
        }
        if !model.accessibilityGranted {
            Divider()
            Button("Allow Accessibility\u{2026}") { model.requestAccessibility() }
        }
        Divider()
        Button("Quit MacTouch") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
