#if canImport(XCTest)
import XCTest
import CoreGraphics
@testable import MacTouchCore

/// Pairs a phone over a real WebSocket and sends signed input frames to the real server,
/// with a recording poster in place of the real cursor.
final class InputServerTests: XCTestCase {
    typealias Client = ServerIntegrationTests.Client

    private struct Phone {
        let client: Client
        let key: Data
        var seq = 0

        mutating func frame(_ events: String, mac override: String? = nil, seq forced: Int? = nil) -> [String: Any] {
            seq += 1
            let n = forced ?? seq
            let body = "{\"ev\":[\(events)]}"
            let mac = override ?? Handshake.inputMac(key: key, seq: n, body: body).base64URLEncodedString()
            return ["type": "input", "seq": n, "t": n * 8, "body": body, "mac": mac]
        }
    }

    private func start(port: UInt16, poster: MockPoster) async throws -> (MacTouchServer, ServerIntegrationTests.TestDelegate, Phone) {
        let suite = UserDefaults(suiteName: "mactouch.tests.\(UUID().uuidString)")!
        let server = MacTouchServer(serverName: "Test Mac", serverId: "server-test-0001", secrets: InMemorySecretStore(),
                                    devices: PairedDeviceStore(defaults: suite), port: port,
                                    input: InputEngine(poster: poster))
        let delegate = ServerIntegrationTests.TestDelegate()
        server.delegate = delegate
        let running = expectation(description: "running")
        delegate.onState = { if case .running = $0 { running.fulfill() } }
        server.start()
        await fulfillment(of: [running], timeout: 5)

        let payload = try XCTUnwrap(server.qrPayload(host: "127.0.0.1"))
        let token = try XCTUnwrap(Data(base64URLEncoded: payload.token))
        let deviceId = "phone-" + Crypto.randomBytes(9).base64URLEncodedString()
        let client = Client.connect(port: payload.port)
        let sn = try XCTUnwrap(try await client.receive()["serverNonce"] as? String)
        let cn = Crypto.randomBytes(16).base64URLEncodedString()
        try await client.send(["type": "pair_request", "deviceId": deviceId, "deviceName": "Test phone", "clientNonce": cn,
                               "proof": Handshake.pairProof(token: token, deviceId: deviceId, clientNonce: cn, serverNonce: sn).base64URLEncodedString()])
        XCTAssertEqual(try await client.receive()["type"] as? String, "pair_pending")
        let accepted = try await client.receive()
        XCTAssertEqual(accepted["type"] as? String, "pair_accepted")
        XCTAssertEqual(accepted["accessibility"] as? Bool, poster.trusted)
        let secret = Handshake.deriveSecret(token: token, deviceId: deviceId, clientNonce: cn, serverNonce: sn)
        return (server, delegate, Phone(client: client, key: Handshake.sessionKey(secret: secret, clientNonce: cn, serverNonce: sn)))
    }

    /// The server handles frames in order, so a pong proves everything before it was processed.
    private func barrier(_ client: Client) async throws {
        try await client.send(["type": "ping", "t": 1])
        let pong = try await client.receive()
        XCTAssertEqual(pong["type"] as? String, "pong")
        XCTAssertEqual(pong["t"] as? Int, 1, "pong echoes the ping timestamp")
    }

    func testSignedFramesMoveTheCursorAndDisconnectReleasesButtons() async throws {
        let poster = MockPoster()
        var (server, delegate, phone) = try await start(port: 48611, poster: poster)
        defer { server.stop(); _ = delegate }

        try await phone.client.send(phone.frame("{\"e\":\"move\",\"dx\":5,\"dy\":3},{\"e\":\"btn\",\"b\":\"left\",\"s\":\"down\",\"n\":1}"))
        try await phone.client.send(phone.frame("{\"e\":\"move\",\"dx\":1,\"dy\":0},{\"e\":\"scroll\",\"dx\":0,\"dy\":7}"))
        try await barrier(phone.client)
        XCTAssertEqual(poster.log, ["move 105,103 d=5,3 drag=-", "left down n=1", "move 106,103 d=1,0 drag=left", "scroll 0,7"])

        phone.client.task.cancel(with: .goingAway, reason: nil)     // phone vanishes while the button is down
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(poster.log.last, "left up n=1", "a vanished phone must not leave the button pressed")
    }

    func testBadMacReplayAndMalformedCommandsEndTheSessionAndReleaseEverything() async throws {
        let cases: [(String, (inout Phone) -> [String: Any], String)] = [
            ("bad mac", { $0.frame("{\"e\":\"move\",\"dx\":1,\"dy\":1}", mac: "AAAA") }, "bad_mac"),
            ("replayed sequence", { $0.frame("{\"e\":\"move\",\"dx\":1,\"dy\":1}", seq: 1) }, "bad_sequence"),
            ("invalid event", { $0.frame("{\"e\":\"move\",\"dx\":99999,\"dy\":0}") }, "invalid_command"),
        ]
        for (index, (name, make, reason)) in cases.enumerated() {
            let poster = MockPoster()
            var (server, delegate, phone) = try await start(port: UInt16(48620 + index), poster: poster)
            defer { server.stop(); _ = delegate }

            try await phone.client.send(phone.frame("{\"e\":\"btn\",\"b\":\"left\",\"s\":\"down\",\"n\":1}"))
            try await barrier(phone.client)
            XCTAssertEqual(poster.log, ["left down n=1"], name)

            try await phone.client.send(make(&phone))
            let reply = try await phone.client.receive()
            XCTAssertEqual(reply["type"] as? String, "error", name)
            XCTAssertEqual(reply["reason"] as? String, reason, name)
            XCTAssertEqual(poster.log.last, "left up n=1", "\(name): button must be released")
            server.stop()
        }
    }

    func testControlMessagesWithoutSignatureNeverReachTheEngine() async throws {
        let poster = MockPoster()
        var (server, delegate, phone) = try await start(port: 48630, poster: poster)
        defer { server.stop(); _ = delegate }
        try await phone.client.send(["type": "input", "seq": 1, "t": 0, "body": "{\"ev\":[{\"e\":\"move\",\"dx\":50,\"dy\":50}]}"])
        let reply = try await phone.client.receive()
        XCTAssertEqual(reply["type"] as? String, "error")
        XCTAssertTrue(poster.log.isEmpty)
    }
}
#endif
