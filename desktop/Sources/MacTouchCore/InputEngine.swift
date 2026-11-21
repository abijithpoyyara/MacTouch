import Foundation
import CoreGraphics

/// Low-level output. `CGEventPoster` is the real implementation; tests use a recording mock.
public protocol EventPoster: AnyObject {
    /// True when macOS has granted this process the Accessibility permission.
    var isTrusted: Bool { get }
    func currentLocation() -> CGPoint
    func displayBounds() -> CGRect
    func mouseMove(to point: CGPoint, deltaX: Int, deltaY: Int, dragging: MouseButton?)
    func mouseButton(_ button: MouseButton, down: Bool, at point: CGPoint, clickCount: Int)
    func scroll(dx: Int, dy: Int)
    func key(code: UInt16, down: Bool, flags: UInt64)
    /// Modifier key press/release (a flagsChanged event on the real implementation). Defaults to a plain key event.
    func modifier(code: UInt16, down: Bool, flags: UInt64)
}

public extension EventPoster {
    func modifier(code: UInt16, down: Bool, flags: UInt64) { key(code: code, down: down, flags: flags) }
}

/// Turns validated `InputEvent`s into system events and tracks which buttons and keys are down,
/// so they can always be released (disconnect, stop, connection loss, invalid command).
public final class InputEngine {
    private let poster: EventPoster
    private let lock = NSLock()
    private var buttons: [MouseButton: Int] = [:]    // button -> click count used for the down event
    private var keys = Set<UInt16>()

    private let launcher: AppLauncher
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    private var generation = 0          // bumped by releaseAll; cancels pending shortcut-hold releases
    private var holdsPending = 0

    /// `schedule` runs a closure after a delay (shortcut hold times). Tests pass a manual scheduler.
    public init(poster: EventPoster,
                launcher: AppLauncher = NSWorkspaceLauncher(),
                schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay, execute: work)
                }) {
        self.poster = poster
        self.launcher = launcher
        self.schedule = schedule
    }

    public var isTrusted: Bool { poster.isTrusted }

    public var pressedButtons: Set<MouseButton> { lock.lock(); defer { lock.unlock() }; return Set(buttons.keys) }
    public var pressedKeys: Set<UInt16> { lock.lock(); defer { lock.unlock() }; return keys }

    public func apply(_ events: [InputEvent]) {
        lock.lock(); defer { lock.unlock() }
        guard poster.isTrusted else {
            // Never act without permission, and never keep phantom state.
            buttons.removeAll(); keys.removeAll()
            // Opening an app (Mission Control) needs no Accessibility permission.
            for case .system(let action) in events {
                if case let .openApp(path) = SystemActionPlanner.plan(for: action) { _ = launcher.openApplication(atPath: path) }
            }
            return
        }
        let bounds = poster.displayBounds()
        var position = poster.currentLocation()

        for event in events {
            switch event {
            case let .move(dx, dy):
                position = Self.clamp(CGPoint(x: position.x + CGFloat(dx), y: position.y + CGFloat(dy)), to: bounds)
                let dragging: MouseButton? = buttons[.left] != nil ? .left : (buttons[.right] != nil ? .right : nil)
                poster.mouseMove(to: position, deltaX: dx, deltaY: dy, dragging: dragging)

            case let .button(button, down, count):
                if down {
                    guard buttons[button] == nil else { continue }       // already down
                    buttons[button] = count
                    poster.mouseButton(button, down: true, at: position, clickCount: count)
                } else {
                    guard let usedCount = buttons.removeValue(forKey: button) else { continue }   // was not down
                    poster.mouseButton(button, down: false, at: position, clickCount: usedCount)
                }

            case let .scroll(dx, dy):
                poster.scroll(dx: dx, dy: dy)

            case let .key(code, down, modifiers):
                if down {
                    keys.insert(code)
                } else {
                    guard keys.remove(code) != nil else { continue }
                }
                poster.key(code: code, down: down, flags: Self.flags(for: modifiers))

            case let .shortcut(code, modifiers, holdMs):
                runShortcutLocked(code: code, modifiers: modifiers, holdMs: holdMs)

            case let .system(action):
                runSystemLocked(action)

            case .releaseAll:
                releaseLocked()
            }
        }
    }

    // MARK: Shortcuts and system actions (Part 3)

    private static let maxPendingHolds = 16

    /// Modifier down (in order), key down, [hold], key up, modifier up (reverse order). Everything that is pressed is
    /// tracked, so `releaseAll` can always undo a half-finished shortcut.
    private func runShortcutLocked(code: UInt16, modifiers: Int, holdMs: Int) {
        let sequence = ShortcutSequencer.sequence(code: code, modifiers: modifiers)
        perform(sequence.press)
        guard holdMs > 0, holdsPending < Self.maxPendingHolds else {
            perform(sequence.release)
            return
        }
        holdsPending += 1
        let gen = generation
        schedule(TimeInterval(holdMs) / 1000) { [weak self] in
            guard let self else { return }
            self.lock.lock(); defer { self.lock.unlock() }
            self.holdsPending -= 1
            guard gen == self.generation else { return }      // releaseAll already let go of everything
            self.perform(sequence.release)
        }
    }

    private func runSystemLocked(_ action: SystemAction) {
        switch SystemActionPlanner.plan(for: action) {
        case let .openApp(path):
            if !launcher.openApplication(atPath: path),
               let fallback = SystemActionPlanner.fallback(for: action),
               case let .shortcut(code, mods) = fallback {
                runShortcutLocked(code: code, modifiers: mods, holdMs: 0)
            }
        case let .shortcut(code, mods):
            runShortcutLocked(code: code, modifiers: mods, holdMs: 0)
        }
    }

    private func perform(_ steps: [KeyStep]) {
        for step in steps {
            if step.down {
                keys.insert(step.code)
            } else {
                guard keys.remove(step.code) != nil else { continue }
            }
            if step.isModifier {
                poster.modifier(code: step.code, down: step.down, flags: step.flags)
            } else {
                poster.key(code: step.code, down: step.down, flags: step.flags)
            }
        }
    }

    /// Releases every pressed button and key. Safe from any thread, safe to call repeatedly.
    public func releaseAll() {
        lock.lock(); defer { lock.unlock() }
        releaseLocked()
    }

    private func releaseLocked() {
        generation += 1          // any scheduled shortcut release is now redundant
        guard !buttons.isEmpty || !keys.isEmpty else { return }
        if poster.isTrusted {
            let at = poster.currentLocation()
            for (button, count) in buttons { poster.mouseButton(button, down: false, at: at, clickCount: count) }
            for code in keys {
                if ShortcutSequencer.isModifierCode(code) {
                    poster.modifier(code: code, down: false, flags: 0)
                } else {
                    poster.key(code: code, down: false, flags: 0)
                }
            }
        }
        buttons.removeAll()
        keys.removeAll()
    }

    static func clamp(_ p: CGPoint, to bounds: CGRect) -> CGPoint {
        guard !bounds.isEmpty else { return p }
        return CGPoint(x: min(max(p.x, bounds.minX), bounds.maxX - 1),
                       y: min(max(p.y, bounds.minY), bounds.maxY - 1))
    }

    /// shift 1, control 2, option 4, command 8 -> CGEventFlags raw value.
    static func flags(for modifiers: Int) -> UInt64 {
        var raw: UInt64 = 0
        if modifiers & 1 != 0 { raw |= CGEventFlags.maskShift.rawValue }
        if modifiers & 2 != 0 { raw |= CGEventFlags.maskControl.rawValue }
        if modifiers & 4 != 0 { raw |= CGEventFlags.maskAlternate.rawValue }
        if modifiers & 8 != 0 { raw |= CGEventFlags.maskCommand.rawValue }
        return raw
    }
}
