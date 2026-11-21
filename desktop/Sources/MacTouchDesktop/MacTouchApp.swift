import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Applied here, after launch. Doing it while SwiftUI builds its scenes (inside AppModel.init) loops forever.
        let showDock = UserDefaults.standard.object(forKey: "mactouch.dockIcon") as? Bool ?? true
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// MacTouch keeps running (server, menu bar item) when its windows are closed. Quit from the menu.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct MacTouchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("MacTouch", id: "main") {
            ContentView().environmentObject(model)
        }
        .windowResizability(.contentMinSize)

        Window("Pair a Phone", id: "pair") {
            PairWindow().environmentObject(model)
        }
        .windowResizability(.contentSize)

        MenuBarExtra(isInserted: Binding(get: { model.showMenuBarIcon }, set: { if model.showMenuBarIcon != $0 { model.showMenuBarIcon = $0 } })) {
            MenuBarView().environmentObject(model)
        } label: {
            Image(systemName: model.menuSymbol)
        }
        .menuBarExtraStyle(.menu)
    }
}
