#if canImport(XCTest)
import XCTest
import CoreGraphics
@testable import MacTouchCore

private let shift = CGEventFlags.maskShift.rawValue
private let control = CGEventFlags.maskControl.rawValue
private let option = CGEventFlags.maskAlternate.rawValue
private let command = CGEventFlags.maskCommand.rawValue

final class MockLauncher: AppLauncher {
    var opened: [String] = []
    var succeeds = true
    func openApplication(atPath path: String) -> Bool { opened.append(path); return succeeds }
}

/// Runs scheduled closures only when the test says so.
final class ManualScheduler {
    private(set) var pending: [(delay: TimeInterval, work: () -> Void)] = []
    func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) { pending.append((delay, work)) }
    func runAll() { let items = pending; pending = []; items.forEach { $0.work() } }
}

final class ShortcutSequenceTests: XCTestCase {
    func testCommandTIsModifierDownKeyDownKeyUpModifierUp() {
        let s = ShortcutSequencer.sequence(code: 17, modifiers: 8)
        XCTAssertEqual(s.press, [KeyStep(code: 55, down: true, flags: command, isModifier: true),
                                 KeyStep(code: 17, down: true, flags: command, isModifier: false)])
        XCTAssertEqual(s.release, [KeyStep(code: 17, down: false, flags: command, isModifier: false),
                                   KeyStep(code: 55, down: false, flags: 0, isModifier: true)])
    }

    func testNoModifiersIsJustTheKey() {
        let s = ShortcutSequencer.sequence(code: 36, modifiers: 0)
        XCTAssertEqual(s.press, [KeyStep(code: 36, down: true, flags: 0, isModifier: false)])
        XCTAssertEqual(s.release, [KeyStep(code: 36, down: false, flags: 0, isModifier: false)])
    }

    func testAllFourModifiersPressInOrderAndReleaseInReverseWithShrinkingFlags() {
        let s = ShortcutSequencer.sequence(code: 0, modifiers: 15)
        XCTAssertEqual(s.press.map(\.code), [59, 58, 56, 55, 0], "control, option, shift, command, then the key")
        XCTAssertEqual(s.press.map(\.flags), [control, control | option, control | option | shift,
                                              control | option | shift | command, control | option | shift | command])
        XCTAssertEqual(s.release.map(\.code), [0, 55, 56, 58, 59], "key up, then command, shift, option, control")
        XCTAssertEqual(s.release.map(\.flags), [control | option | shift | command, control | option | shift,
                                                control | option, control, 0])
        XCTAssertTrue(s.press.dropLast().allSatisfy { $0.isModifier && $0.down })
        XCTAssertTrue(s.release.dropFirst().allSatisfy { $0.isModifier && !$0.down })
    }

    func testEveryPressedModifierIsReleasedExactlyOnce() {
        for mask in 0...15 {
            let s = ShortcutSequencer.sequence(code: 5, modifiers: mask)
            let down = s.press.filter(\.isModifier).map(\.code)
            let up = s.release.filter(\.isModifier).map(\.code)
            XCTAssertEqual(Array(down.reversed()), up, "mask \(mask)")
            XCTAssertEqual(s.release.last?.flags, 0, "mask \(mask): nothing may stay flagged")
        }
    }

    func testModifierCodes() {
        for code: UInt16 in [54, 55, 56, 58, 59, 60, 61, 62] { XCTAssertTrue(ShortcutSequencer.isModifierCode(code)) }
        for code: UInt16 in [0, 17, 36, 57, 103, 126] { XCTAssertFalse(ShortcutSequencer.isModifierCode(code)) }
    }
}

final class ShortcutParserTests: XCTestCase {
    private func body(_ e: String) -> String { "{\"ev\":[\(e)]}" }

    func testParsesShortcutAndSystemEvents() throws {
        let events = try InputParser.parse(body("""
        {"e":"shortcut","c":17,"m":8},{"e":"shortcut","c":48,"m":8,"h":600},{"e":"sys","a":"mission_control"},{"e":"sys","a":"desktop_left"}
        """))
        XCTAssertEqual(events, [.shortcut(code: 17, modifiers: 8, holdMs: 0), .shortcut(code: 48, modifiers: 8, holdMs: 600),
                                .system(.missionControl), .system(.desktopLeft)])
    }

    func testRejectsInvalidShortcutAndSystemEvents() {
        let bad = [
            body("{\"e\":\"shortcut\",\"m\":8}"),
            body("{\"e\":\"shortcut\",\"c\":256}"),
            body("{\"e\":\"shortcut\",\"c\":-1}"),
            body("{\"e\":\"shortcut\",\"c\":1,\"m\":16}"),
            body("{\"e\":\"shortcut\",\"c\":1,\"h\":5001}"),
            body("{\"e\":\"shortcut\",\"c\":1,\"h\":-5}"),
            body("{\"e\":\"shortcut\",\"c\":1.5}"),
            body("{\"e\":\"sys\"}"),
            body("{\"e\":\"sys\",\"a\":\"reboot\"}"),
            body("{\"e\":\"sys\",\"a\":7}"),
        ]
        for text in bad { XCTAssertThrowsError(try InputParser.parse(text), text) }
    }
}

final class SystemActionPlannerTests: XCTestCase {
    func testPlans() {
        XCTAssertEqual(SystemActionPlanner.plan(for: .missionControl), .openApp(path: "/System/Applications/Mission Control.app"))
        XCTAssertEqual(SystemActionPlanner.plan(for: .appExpose), .shortcut(code: 125, modifiers: 2))
        XCTAssertEqual(SystemActionPlanner.plan(for: .desktopLeft), .shortcut(code: 123, modifiers: 2))
        XCTAssertEqual(SystemActionPlanner.plan(for: .desktopRight), .shortcut(code: 124, modifiers: 2))
        XCTAssertEqual(SystemActionPlanner.plan(for: .showDesktop), .shortcut(code: 103, modifiers: 0))
        XCTAssertEqual(SystemActionPlanner.fallback(for: .missionControl), .shortcut(code: 126, modifiers: 2))
        XCTAssertNil(SystemActionPlanner.fallback(for: .appExpose))
    }

    func testEveryActionHasARequirementText() {
        for a in SystemAction.allCases { XCTAssertFalse(SystemActionPlanner.requirement(for: a).isEmpty) }
    }
}

final class ShortcutEngineTests: XCTestCase {
    private func make(trusted: Bool = true, launcherOK: Bool = true)
        -> (InputEngine, MockPoster, MockLauncher, ManualScheduler) {
        let poster = MockPoster()
        poster.trusted = trusted
        let launcher = MockLauncher()
        launcher.succeeds = launcherOK
        let scheduler = ManualScheduler()
        let engine = InputEngine(poster: poster, launcher: launcher, schedule: scheduler.schedule)
        return (engine, poster, launcher, scheduler)
    }

    func testShortcutPostsTheFullModifierSequence() {
        let (engine, poster, _, _) = make()
        engine.apply([.shortcut(code: 17, modifiers: 8 | 1, holdMs: 0)])        // Shift + Command + T
        XCTAssertEqual(poster.log, [
            "key 56 down f=\(shift)",
            "key 55 down f=\(shift | command)",
            "key 17 down f=\(shift | command)",
            "key 17 up f=\(shift | command)",
            "key 55 up f=\(shift)",
            "key 56 up f=0",
        ])
        XCTAssertTrue(engine.pressedKeys.isEmpty, "nothing left pressed")
    }

    func testHoldKeepsKeysDownUntilTheTimerFires() {
        let (engine, poster, _, scheduler) = make()
        engine.apply([.shortcut(code: 48, modifiers: 8, holdMs: 600)])           // Command + Tab, hold 600 ms
        XCTAssertEqual(poster.log, ["key 55 down f=\(command)", "key 48 down f=\(command)"])
        XCTAssertEqual(engine.pressedKeys, [55, 48])
        XCTAssertEqual(scheduler.pending.count, 1)
        XCTAssertEqual(scheduler.pending[0].delay, 0.6, accuracy: 0.0001)
        scheduler.runAll()
        XCTAssertEqual(poster.log.suffix(2), ["key 48 up f=\(command)", "key 55 up f=0"])
        XCTAssertTrue(engine.pressedKeys.isEmpty)
    }

    func testReleaseAllDuringAHoldReleasesNowAndTheTimerDoesNothingLater() {
        let (engine, poster, _, scheduler) = make()
        engine.apply([.shortcut(code: 48, modifiers: 8, holdMs: 600)])
        engine.releaseAll()
        XCTAssertTrue(engine.pressedKeys.isEmpty)
        XCTAssertTrue(poster.log.contains("key 48 up f=0"))
        XCTAssertTrue(poster.log.contains("key 55 up f=0"))
        let count = poster.log.count
        scheduler.runAll()
        XCTAssertEqual(poster.log.count, count, "the stale timer must not post anything")
    }

    func testShortcutsAreIgnoredWithoutAccessibility() {
        let (engine, poster, launcher, _) = make(trusted: false)
        engine.apply([.shortcut(code: 17, modifiers: 8, holdMs: 0), .system(.appExpose)])
        XCTAssertTrue(poster.log.isEmpty)
        XCTAssertTrue(launcher.opened.isEmpty)
    }

    func testMissionControlOpensTheAppEvenWithoutAccessibility() {
        let (engine, poster, launcher, _) = make(trusted: false)
        engine.apply([.system(.missionControl)])
        XCTAssertEqual(launcher.opened, ["/System/Applications/Mission Control.app"])
        XCTAssertTrue(poster.log.isEmpty)
    }

    func testMissionControlFallsBackToControlUpIfTheAppCannotOpen() {
        let (engine, poster, launcher, _) = make(launcherOK: false)
        engine.apply([.system(.missionControl)])
        XCTAssertEqual(launcher.opened.count, 1)
        XCTAssertEqual(poster.log, ["key 59 down f=\(control)", "key 126 down f=\(control)",
                                    "key 126 up f=\(control)", "key 59 up f=0"])
    }

    func testDesktopSwitchingAndExposeSendControlArrows() {
        let (engine, poster, _, _) = make()
        engine.apply([.system(.desktopLeft)])
        XCTAssertEqual(poster.log.filter { !$0.contains("key 59") }, ["key 123 down f=\(control)", "key 123 up f=\(control)"])
        engine.apply([.system(.desktopRight)])
        XCTAssertTrue(poster.log.contains("key 124 down f=\(control)"))
        engine.apply([.system(.appExpose)])
        XCTAssertTrue(poster.log.contains("key 125 down f=\(control)"))
        engine.apply([.system(.showDesktop)])
        XCTAssertTrue(poster.log.contains("key 103 down f=0"))
    }

    func testTooManyHoldsAreNotAllowedToPileUp() {
        let (engine, poster, _, scheduler) = make()
        for _ in 0..<40 { engine.apply([.shortcut(code: 4, modifiers: 0, holdMs: 1000)]) }
        XCTAssertLessThanOrEqual(scheduler.pending.count, 16)
        scheduler.runAll()
        engine.releaseAll()
        XCTAssertTrue(engine.pressedKeys.isEmpty)
        _ = poster
    }
}
#endif
