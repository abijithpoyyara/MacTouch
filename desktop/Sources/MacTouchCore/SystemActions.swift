import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// macOS actions that are not plain shortcuts. Each one has a documented way of running and a documented requirement.
public enum SystemAction: String, CaseIterable {
    case missionControl = "mission_control"
    case appExpose = "app_expose"
    case desktopLeft = "desktop_left"
    case desktopRight = "desktop_right"
    case showDesktop = "show_desktop"
}

public enum SystemActionPlan: Equatable {
    /// Launch an app (needs no Accessibility permission and no keyboard-shortcut setting).
    case openApp(path: String)
    /// Post a keyboard shortcut (needs Accessibility, and the matching macOS keyboard shortcut enabled).
    case shortcut(code: UInt16, modifiers: Int)
}

public enum SystemActionPlanner {
    public static let missionControlApp = "/System/Applications/Mission Control.app"

    public static func plan(for action: SystemAction) -> SystemActionPlan {
        switch action {
        case .missionControl: return .openApp(path: missionControlApp)
        case .appExpose:      return .shortcut(code: 125, modifiers: 2)   // Control + Down
        case .desktopLeft:    return .shortcut(code: 123, modifiers: 2)   // Control + Left
        case .desktopRight:   return .shortcut(code: 124, modifiers: 2)   // Control + Right
        case .showDesktop:    return .shortcut(code: 103, modifiers: 0)   // F11
        }
    }

    /// Used when the primary plan cannot run (for example the Mission Control app is missing).
    public static func fallback(for action: SystemAction) -> SystemActionPlan? {
        action == .missionControl ? .shortcut(code: 126, modifiers: 2) : nil   // Control + Up
    }

    /// Plain-language requirement, shown in documentation and in the phone app.
    public static func requirement(for action: SystemAction) -> String {
        switch action {
        case .missionControl:
            return "None. Opens the Mission Control app, so it works even if the keyboard shortcut is turned off."
        case .appExpose:
            return "Needs the \"Application windows\" shortcut (Control-Down Arrow) turned on in System Settings > Keyboard > Keyboard Shortcuts > Mission Control, and the Accessibility permission."
        case .desktopLeft, .desktopRight:
            return "Needs the \"Move left/right a space\" shortcuts (Control-Left/Right Arrow) turned on in System Settings > Keyboard > Keyboard Shortcuts > Mission Control, at least two desktops, and the Accessibility permission."
        case .showDesktop:
            return "Needs the \"Show Desktop\" shortcut (F11 by default) turned on in System Settings > Keyboard > Keyboard Shortcuts > Mission Control, and the Accessibility permission."
        }
    }
}

public protocol AppLauncher: AnyObject {
    /// Returns false if the app could not be launched.
    func openApplication(atPath path: String) -> Bool
}

public final class NSWorkspaceLauncher: AppLauncher {
    public init() {}

    public func openApplication(atPath path: String) -> Bool {
        #if canImport(AppKit)
        guard FileManager.default.fileExists(atPath: path) else { return false }
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path),
                                           configuration: NSWorkspace.OpenConfiguration(),
                                           completionHandler: nil)
        return true
        #else
        return false
        #endif
    }
}
