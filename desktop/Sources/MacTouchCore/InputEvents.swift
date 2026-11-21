import Foundation

public enum MouseButton: String {
    case left, right
}

public enum InputEvent: Equatable {
    case move(dx: Int, dy: Int)
    case button(MouseButton, down: Bool, clickCount: Int)
    case scroll(dx: Int, dy: Int)
    /// `modifiers` bitmask: shift 1, control 2, option 4, command 8.
    case key(code: UInt16, down: Bool, modifiers: Int)
    case releaseAll
    /// Part 3: a full keyboard shortcut (modifier down, key down, key up, modifier up), optionally held for `holdMs`.
    case shortcut(code: UInt16, modifiers: Int, holdMs: Int)
    /// Part 3: a macOS system action (Mission Control, desktops ...).
    case system(SystemAction)
}

public enum InputParseError: Error, Equatable {
    case notJSON
    case tooManyEvents
    case unknownEvent(String)
    case invalidField(String)
    case outOfRange(String)
}

/// Strict validation of the (already MAC-verified) body of an input frame.
///
///     {"ev":[{"e":"move","dx":5,"dy":-3},{"e":"btn","b":"left","s":"down","n":1},
///            {"e":"scroll","dx":0,"dy":12},{"e":"key","c":36,"s":"down","m":0},{"e":"release"}]}
public enum InputParser {
    /// Integer value of a JSON number. Rejects booleans, fractions, NaN and absurd magnitudes.
    public static func int(_ any: Any?) -> Int? {
        guard let n = any as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        let d = n.doubleValue
        guard d.isFinite, d == d.rounded(), abs(d) < 1e12 else { return nil }
        return Int(d)
    }

    public static func parse(_ body: String) throws -> [InputEvent] {
        guard let data = body.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = root["ev"] as? [Any] else { throw InputParseError.notJSON }
        guard list.count <= InputLimits.maxEventsPerFrame else { throw InputParseError.tooManyEvents }
        return try list.map { try parseEvent($0) }
    }

    private static func parseEvent(_ raw: Any) throws -> InputEvent {
        guard let e = raw as? [String: Any], let kind = e["e"] as? String else {
            throw InputParseError.invalidField("e")
        }
        switch kind {
        case "move":
            guard let dx = int(e["dx"]), let dy = int(e["dy"]) else { throw InputParseError.invalidField("dx/dy") }
            guard abs(dx) <= InputLimits.maxMoveDelta, abs(dy) <= InputLimits.maxMoveDelta else {
                throw InputParseError.outOfRange("move")
            }
            return .move(dx: dx, dy: dy)

        case "btn":
            guard let name = e["b"] as? String, let button = MouseButton(rawValue: name) else {
                throw InputParseError.invalidField("b")
            }
            guard let state = e["s"] as? String, state == "down" || state == "up" else {
                throw InputParseError.invalidField("s")
            }
            let n = e["n"] == nil ? 1 : (int(e["n"]) ?? 0)
            guard (1...3).contains(n) else { throw InputParseError.outOfRange("n") }
            return .button(button, down: state == "down", clickCount: n)

        case "scroll":
            guard let dx = int(e["dx"]), let dy = int(e["dy"]) else { throw InputParseError.invalidField("dx/dy") }
            guard abs(dx) <= InputLimits.maxScrollDelta, abs(dy) <= InputLimits.maxScrollDelta else {
                throw InputParseError.outOfRange("scroll")
            }
            return .scroll(dx: dx, dy: dy)

        case "key":
            guard let code = int(e["c"]) else { throw InputParseError.invalidField("c") }
            guard (0...InputLimits.maxKeyCode).contains(code) else { throw InputParseError.outOfRange("c") }
            guard let state = e["s"] as? String, state == "down" || state == "up" else {
                throw InputParseError.invalidField("s")
            }
            let mods = e["m"] == nil ? 0 : (int(e["m"]) ?? -1)
            guard (0...15).contains(mods) else { throw InputParseError.outOfRange("m") }
            return .key(code: UInt16(code), down: state == "down", modifiers: mods)

        case "shortcut":
            guard let code = int(e["c"]) else { throw InputParseError.invalidField("c") }
            guard (0...InputLimits.maxKeyCode).contains(code) else { throw InputParseError.outOfRange("c") }
            let mods = e["m"] == nil ? 0 : (int(e["m"]) ?? -1)
            guard (0...15).contains(mods) else { throw InputParseError.outOfRange("m") }
            let hold = e["h"] == nil ? 0 : (int(e["h"]) ?? -1)
            guard (0...ShortcutLimits.maxHoldMs).contains(hold) else { throw InputParseError.outOfRange("h") }
            return .shortcut(code: UInt16(code), modifiers: mods, holdMs: hold)

        case "sys":
            guard let name = e["a"] as? String, let action = SystemAction(rawValue: name) else {
                throw InputParseError.invalidField("a")
            }
            return .system(action)

        case "release":
            return .releaseAll

        default:
            throw InputParseError.unknownEvent(kind)
        }
    }
}
