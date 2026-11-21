#if canImport(XCTest)
import XCTest
import CoreGraphics
@testable import MacTouchCore

/// Records every call instead of touching the real cursor.
final class MockPoster: EventPoster {
    var trusted = true
    var location = CGPoint(x: 100, y: 100)
    var bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let lock = NSLock()
    private var entries: [String] = []

    var log: [String] { lock.lock(); defer { lock.unlock() }; return entries }
    private func record(_ s: String) { lock.lock(); entries.append(s); lock.unlock() }

    var isTrusted: Bool { trusted }
    func currentLocation() -> CGPoint { location }
    func displayBounds() -> CGRect { bounds }
    func mouseMove(to point: CGPoint, deltaX: Int, deltaY: Int, dragging: MouseButton?) {
        location = point
        record("move \(Int(point.x)),\(Int(point.y)) d=\(deltaX),\(deltaY) drag=\(dragging?.rawValue ?? "-")")
    }
    func mouseButton(_ button: MouseButton, down: Bool, at point: CGPoint, clickCount: Int) {
        record("\(button.rawValue) \(down ? "down" : "up") n=\(clickCount)")
    }
    func scroll(dx: Int, dy: Int) { record("scroll \(dx),\(dy)") }
    func key(code: UInt16, down: Bool, flags: UInt64) { record("key \(code) \(down ? "down" : "up") f=\(flags)") }
}

private func body(_ events: String) -> String { "{\"ev\":[\(events)]}" }

final class InputParserTests: XCTestCase {
    func testParsesEveryEventType() throws {
        let events = try InputParser.parse(body("""
        {"e":"move","dx":5,"dy":-3},{"e":"btn","b":"left","s":"down","n":2},{"e":"btn","b":"right","s":"up"},
        {"e":"scroll","dx":0,"dy":12},{"e":"key","c":36,"s":"down","m":9},{"e":"release"}
        """))
        XCTAssertEqual(events, [
            .move(dx: 5, dy: -3),
            .button(.left, down: true, clickCount: 2),
            .button(.right, down: false, clickCount: 1),
            .scroll(dx: 0, dy: 12),
            .key(code: 36, down: true, modifiers: 9),
            .releaseAll,
        ])
    }

    func testRejectsMalformedAndOutOfRange() {
        let bad: [String] = [
            "not json", "[]", "{}", "{\"ev\":5}",
            body("{\"e\":\"teleport\"}"),
            body("{\"dx\":1,\"dy\":1}"),
            body("{\"e\":\"move\",\"dx\":1.5,\"dy\":0}"),
            body("{\"e\":\"move\",\"dx\":true,\"dy\":0}"),
            body("{\"e\":\"move\",\"dx\":\"5\",\"dy\":0}"),
            body("{\"e\":\"move\",\"dx\":2001,\"dy\":0}"),
            body("{\"e\":\"scroll\",\"dx\":0,\"dy\":-1001}"),
            body("{\"e\":\"btn\",\"b\":\"middle\",\"s\":\"down\"}"),
            body("{\"e\":\"btn\",\"b\":\"left\",\"s\":\"press\"}"),
            body("{\"e\":\"btn\",\"b\":\"left\",\"s\":\"down\",\"n\":4}"),
            body("{\"e\":\"key\",\"c\":256,\"s\":\"down\"}"),
            body("{\"e\":\"key\",\"c\":-1,\"s\":\"down\"}"),
            body("{\"e\":\"key\",\"c\":4,\"s\":\"down\",\"m\":16}"),
        ]
        for text in bad {
            XCTAssertThrowsError(try InputParser.parse(text), text)
        }
    }

    func testRejectsTooManyEvents() {
        let many = Array(repeating: "{\"e\":\"release\"}", count: InputLimits.maxEventsPerFrame + 1).joined(separator: ",")
        XCTAssertThrowsError(try InputParser.parse(body(many))) {
            XCTAssertEqual($0 as? InputParseError, .tooManyEvents)
        }
        let ok = Array(repeating: "{\"e\":\"release\"}", count: InputLimits.maxEventsPerFrame).joined(separator: ",")
        XCTAssertNoThrow(try InputParser.parse(body(ok)))
    }
}

final class InputEngineTests: XCTestCase {
    func testMoveIsRelativeAndClampedToDisplays() {
        let poster = MockPoster()
        poster.location = CGPoint(x: 1900, y: 5)
        InputEngine(poster: poster).apply([.move(dx: 50, dy: -50)])
        XCTAssertEqual(poster.log, ["move 1919,0 d=50,-50 drag=-"])
    }

    func testButtonStateAndDragEvents() {
        let poster = MockPoster()
        let engine = InputEngine(poster: poster)
        engine.apply([.button(.left, down: true, clickCount: 1), .move(dx: 4, dy: 0), .button(.left, down: false, clickCount: 1)])
        XCTAssertEqual(poster.log, ["left down n=1", "move 104,100 d=4,0 drag=left", "left up n=1"])
        XCTAssertTrue(engine.pressedButtons.isEmpty)
    }

    func testDuplicateDownAndStrayUpAreIgnored() {
        let poster = MockPoster()
        let engine = InputEngine(poster: poster)
        engine.apply([.button(.left, down: false, clickCount: 1),
                      .button(.left, down: true, clickCount: 1), .button(.left, down: true, clickCount: 2)])
        XCTAssertEqual(poster.log, ["left down n=1"])
    }

    func testUpReusesTheClickCountOfTheDown() {
        let poster = MockPoster()
        InputEngine(poster: poster).apply([.button(.left, down: true, clickCount: 2), .button(.left, down: false, clickCount: 1)])
        XCTAssertEqual(poster.log, ["left down n=2", "left up n=2"])
    }

    func testReleaseAllReleasesButtonsAndKeys() {
        let poster = MockPoster()
        let engine = InputEngine(poster: poster)
        engine.apply([.button(.left, down: true, clickCount: 1), .button(.right, down: true, clickCount: 1),
                      .key(code: 56, down: true, modifiers: 1)])
        engine.releaseAll()
        XCTAssertTrue(engine.pressedButtons.isEmpty && engine.pressedKeys.isEmpty)
        XCTAssertTrue(poster.log.contains("left up n=1"))
        XCTAssertTrue(poster.log.contains("right up n=1"))
        XCTAssertTrue(poster.log.contains { $0.hasPrefix("key 56 up") })
        let count = poster.log.count
        engine.releaseAll()                      // idempotent
        XCTAssertEqual(poster.log.count, count)
    }

    func testReleaseAllEventInsideAFrame() {
        let poster = MockPoster()
        let engine = InputEngine(poster: poster)
        engine.apply([.button(.left, down: true, clickCount: 1), .releaseAll])
        XCTAssertEqual(poster.log, ["left down n=1", "left up n=1"])
    }

    func testNothingHappensWithoutAccessibilityPermission() {
        let poster = MockPoster()
        poster.trusted = false
        let engine = InputEngine(poster: poster)
        engine.apply([.move(dx: 5, dy: 5), .button(.left, down: true, clickCount: 1), .scroll(dx: 0, dy: 3)])
        XCTAssertTrue(poster.log.isEmpty)
        XCTAssertTrue(engine.pressedButtons.isEmpty, "no phantom pressed state")
    }

    func testScrollAndKeyboard() {
        let poster = MockPoster()
        let engine = InputEngine(poster: poster)
        engine.apply([.scroll(dx: 3, dy: -9), .key(code: 8, down: true, modifiers: 8), .key(code: 8, down: false, modifiers: 8)])
        let cmd = CGEventFlags.maskCommand.rawValue
        XCTAssertEqual(poster.log, ["scroll 3,-9", "key 8 down f=\(cmd)", "key 8 up f=\(cmd)"])
    }
}

final class RateLimiterTests: XCTestCase {
    func testBurstThenRefill() {
        var time: TimeInterval = 0
        var limiter = RateLimiter(capacity: 5, refillPerSecond: 10, now: { time })
        XCTAssertEqual((0..<8).filter { _ in limiter.allow() }.count, 5)
        XCTAssertFalse(limiter.allow())
        time += 0.25                            // refills 2.5 tokens
        XCTAssertTrue(limiter.allow())
        XCTAssertTrue(limiter.allow())
        XCTAssertFalse(limiter.allow())
    }
}

final class InputVectorTests: XCTestCase {
    private struct V: Decodable {
        let secret, clientNonce, serverNonce, sessionKey, inputBody, inputMac: String
        let inputSeq: Int
    }

    func testSessionKeyAndInputMacMatchSharedVectors() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url.deleteLastPathComponent() }
        url.appendPathComponent("protocol/test-vectors.json")
        let v = try JSONDecoder().decode(V.self, from: Data(contentsOf: url))
        let secret = try XCTUnwrap(Data(base64URLEncoded: v.secret))
        let key = Handshake.sessionKey(secret: secret, clientNonce: v.clientNonce, serverNonce: v.serverNonce)
        XCTAssertEqual(key.base64URLEncodedString(), v.sessionKey)
        XCTAssertEqual(Handshake.inputMac(key: key, seq: v.inputSeq, body: v.inputBody).base64URLEncodedString(), v.inputMac)
        XCTAssertNoThrow(try InputParser.parse(v.inputBody), "the vector body must be a valid input body")
    }
}
#endif
