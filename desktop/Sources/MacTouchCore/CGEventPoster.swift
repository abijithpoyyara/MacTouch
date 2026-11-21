import Foundation
import CoreGraphics
import ApplicationServices

/// Posts real mouse, scroll and keyboard events with Core Graphics. Needs the Accessibility permission.
public final class CGEventPoster: EventPoster {
    private let source = CGEventSource(stateID: .hidSystemState)
    private let trustLock = NSLock()
    private var cachedTrust = false
    private var trustCheckedAt: TimeInterval = -10

    public init() {}

    public var isTrusted: Bool {
        trustLock.lock(); defer { trustLock.unlock() }
        let now = ProcessInfo.processInfo.systemUptime
        if now - trustCheckedAt > 0.5 {
            cachedTrust = AXIsProcessTrusted()
            trustCheckedAt = now
        }
        return cachedTrust
    }

    public func currentLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    public func displayBounds() -> CGRect {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return .zero }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return .zero }
        let union = ids.prefix(Int(count)).reduce(CGRect.null) { $0.union(CGDisplayBounds($1)) }
        return union.isNull ? .zero : union
    }

    public func mouseMove(to point: CGPoint, deltaX: Int, deltaY: Int, dragging: MouseButton?) {
        let type: CGEventType
        let button: CGMouseButton
        switch dragging {
        case .left?:  type = .leftMouseDragged;  button = .left
        case .right?: type = .rightMouseDragged; button = .right
        case nil:     type = .mouseMoved;        button = .left
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(deltaX))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(deltaY))
        event.post(tap: .cghidEventTap)
    }

    public func mouseButton(_ button: MouseButton, down: Bool, at point: CGPoint, clickCount: Int) {
        let type: CGEventType
        let cgButton: CGMouseButton
        switch (button, down) {
        case (.left, true):   type = .leftMouseDown;  cgButton = .left
        case (.left, false):  type = .leftMouseUp;    cgButton = .left
        case (.right, true):  type = .rightMouseDown; cgButton = .right
        case (.right, false): type = .rightMouseUp;   cgButton = .right
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: cgButton) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        event.post(tap: .cghidEventTap)
    }

    /// Pixel units. Positive `dy` moves content down (finger moves down, "natural" direction); positive `dx` moves content right.
    public func scroll(dx: Int, dy: Int) {
        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                                  wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }

    public func key(code: UInt16, down: Bool, flags: UInt64) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: down) else { return }
        event.flags = CGEventFlags(rawValue: flags)
        event.post(tap: .cghidEventTap)
    }

    /// Modifier keys are reported with flagsChanged events, like a physical keyboard does.
    public func modifier(code: UInt16, down: Bool, flags: UInt64) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(code), keyDown: down) else { return }
        event.type = .flagsChanged
        event.flags = CGEventFlags(rawValue: flags)
        event.post(tap: .cghidEventTap)
    }
}
