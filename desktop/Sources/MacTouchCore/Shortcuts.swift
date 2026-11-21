import Foundation
import CoreGraphics

// Part 3: keyboard shortcut sequencing. Pure functions, no I/O, so the exact key order is unit-tested.

public enum ShortcutLimits {
    public static let maxHoldMs = 5000
}

/// The four modifier keys, in the order they are pressed: control, option, shift, command.
/// (Released in the reverse order, like a person letting go.)
public enum ModifierKey: CaseIterable {
    case control, option, shift, command

    /// Bit in the protocol's modifier mask (shift 1, control 2, option 4, command 8).
    public var bit: Int {
        switch self {
        case .shift: return 1
        case .control: return 2
        case .option: return 4
        case .command: return 8
        }
    }

    /// macOS virtual key code of the left-hand modifier key.
    public var keyCode: UInt16 {
        switch self {
        case .shift: return 56
        case .control: return 59
        case .option: return 58
        case .command: return 55
        }
    }

    public var flag: UInt64 {
        switch self {
        case .shift: return CGEventFlags.maskShift.rawValue
        case .control: return CGEventFlags.maskControl.rawValue
        case .option: return CGEventFlags.maskAlternate.rawValue
        case .command: return CGEventFlags.maskCommand.rawValue
        }
    }

    /// Modifiers present in `mask`, in press order.
    public static func pressed(in mask: Int) -> [ModifierKey] {
        allCases.filter { mask & $0.bit != 0 }
    }
}

public struct KeyStep: Equatable {
    public let code: UInt16
    public let down: Bool
    /// Modifier flags that are active *after* this step (what the system reports with the event).
    public let flags: UInt64
    public let isModifier: Bool
}

public struct ShortcutSequence: Equatable {
    public let press: [KeyStep]
    public let release: [KeyStep]
}

public enum ShortcutSequencer {
    /// Virtual key codes of the physical modifier keys (left and right, plus fn/caps are not included).
    private static let modifierCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]

    public static func isModifierCode(_ code: UInt16) -> Bool { modifierCodes.contains(code) }

    /// Cmd+T becomes: Command down, T down (with Command flag) ... T up (with Command flag), Command up.
    /// Every key event carries the flags that are active at that moment, so applications that read flags
    /// (most do) and applications that watch modifier key events both see a consistent keyboard.
    public static func sequence(code: UInt16, modifiers: Int) -> ShortcutSequence {
        let mods = ModifierKey.pressed(in: modifiers)
        var press: [KeyStep] = []
        var flags: UInt64 = 0
        for m in mods {
            flags |= m.flag
            press.append(KeyStep(code: m.keyCode, down: true, flags: flags, isModifier: true))
        }
        press.append(KeyStep(code: code, down: true, flags: flags, isModifier: false))

        var release: [KeyStep] = [KeyStep(code: code, down: false, flags: flags, isModifier: false)]
        for m in mods.reversed() {
            flags &= ~m.flag
            release.append(KeyStep(code: m.keyCode, down: false, flags: flags, isModifier: true))
        }
        return ShortcutSequence(press: press, release: release)
    }
}
