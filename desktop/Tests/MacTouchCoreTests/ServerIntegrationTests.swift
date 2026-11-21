#if canImport(XCTest)
import XCTest
@testable import MacTouchCore

/// Drives the real Network.framework server with URLSession WebSocket clients on loopback.
final class ServerIntegrationTests: XCTestCase {

    final class TestDelegate: MacTouchServerDelegate {
        var approve = true
        var onState: ((MacTouchServer.State) -> Void)?
        func server(_ server: MacTouchServer, didChangeState state: MacTouchServer.State) { onState?(state) }
        func server(_ server: MacTouchServer, didReceivePairingRequest request: PairingRequest, respond: @escaping (Bool) -> Void) { respond(approve) }
        func server(_ server: MacTouchServer, pairingRequestEnded id: UUID) {}
        func server(_ server: MacTouchServer, didAuthenticate device: PairedDevice) {}
        func server(_ server: MacTouchServer, didDisconnect device: PairedDevice) {}
        func serverDidRotatePairingToken(_ server: MacTouchServer) {}
    }

    struct Client {
        let task: URLSessionWebSocketTask
        static func connect(port: Int) -> Client {
            let t = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)/")!)
            t.resume()
            return Client(task: t)
        }
        func send(_ fields: [String: Any]) async throws {
            var body = fields; body["v"] = 1
            let data = try JSONSerialization.data(withJSONObject: body)
            try await task.send(.string(String(decoding: data, as: UTF8.self)))
        }
        func receive() async throws -> [String: Any] {
            guard case .string(let text) = try await task.receive(),
                  let obj = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
                throw NSError(domain: "test", code: 1)
            }
            return obj
        }
    }

    private func makeServer(port: UInt16, approve: Bool = true) async throws -> (MacTouchServer, TestDelegate) {
        let suite = UserDefaults(suiteName: "mactouch.tests.\(UUID().uuidString)")!
        let server = MacTouchServer(serverName: "Test Mac", serverId: "server-test-0001", secrets: InMemorySecretStore(),
                                    devices: PairedDeviceStore(defaults: suite), port: port)
        let delegate = TestDelegate()
        delegate.approve = approve
        server.delegate = delegate
        let running = expectation(description: "server running")
        delegate.onState = { if case .running = $0 { running.fulfill() } }
        server.start()
        await fulfillment(of: [running], timeout: 5)
        return (server, delegate)
    }

    func testPairThenReconnect() async throws {
        let (server, delegate) = try await makeServer(port: 48601)
        defer { server.stop(); _ = delegate }

        let payload = try XCTUnwrap(server.qrPayload(host: "127.0.0.1"))
        let token = try XCTUnwrap(Data(base64URLEncoded: payload.token))
        let deviceId = "phone-" + Crypto.randomBytes(9).base64URLEncodedString()

        // Pair
        let c1 = Client.connect(port: payload.port)
        let ch1 = try await c1.receive()
        XCTAssertEqual(ch1["type"] as? String, "challenge")
        let sn1 = try XCTUnwrap(ch1["serverNonce"] as? String)
        let cn1 = Crypto.randomBytes(16).base64URLEncodedString()
        try await c1.send(["type": "pair_request", "deviceId": deviceId, "deviceName": "Test phone", "clientNonce": cn1,
                           "proof": Handshake.pairProof(token: token, deviceId: deviceId, clientNonce: cn1, serverNonce: sn1).base64URLEncodedString()])
        XCTAssertEqual(try await c1.receive()["type"] as? String, "pair_pending")
        let accepted = try await c1.receive()
        XCTAssertEqual(accepted["type"] as? String, "pair_accepted")
        let secret = Handshake.deriveSecret(token: token, deviceId: deviceId, clientNonce: cn1, serverNonce: sn1)
        XCTAssertEqual(accepted["serverProof"] as? String,
                       Handshake.serverProof(secret: secret, clientNonce: cn1, serverNonce: sn1).base64URLEncodedString())

        try await c1.send(["type": "ping"])
        XCTAssertEqual(try await c1.receive()["type"] as? String, "pong")
        try await c1.send(["type": "pointer_move", "dx": 1, "dy": 1])
        XCTAssertEqual(try await c1.receive()["code"] as? String, "unsupported")

        // Reconnect with the derived secret (replaces the first session)
        let c2 = Client.connect(port: payload.port)
        let ch2 = try await c2.receive()
        let sn2 = try XCTUnwrap(ch2["serverNonce"] as? String)
        let cn2 = Crypto.randomBytes(16).base64URLEncodedString()
        try await c2.send(["type": "auth", "deviceId": deviceId, "clientNonce": cn2,
                           "proof": Handshake.authProof(secret: secret, deviceId: deviceId, clientNonce: cn2, serverNonce: sn2).base64URLEncodedString()])
        XCTAssertEqual(try await c2.receive()["type"] as? String, "auth_ok")
    }

    func testUnauthenticatedControlIsRefused() async throws {
        let (server, delegate) = try await makeServer(port: 48602)
        defer { server.stop(); _ = delegate }
        let c = Client.connect(port: 48602)
        _ = try await c.receive()   // challenge
        try await c.send(["type": "pointer_move", "dx": 5, "dy": 5])
        let reply = try await c.receive()
        XCTAssertEqual(reply["type"] as? String, "error")
        XCTAssertEqual(reply["reason"] as? String, "unauthenticated")
    }

    func testDeclinedPairingIsRejected() async throws {
        let (server, delegate) = try await makeServer(port: 48603, approve: false)
        defer { server.stop(); _ = delegate }
        let payload = try XCTUnwrap(server.qrPayload(host: "127.0.0.1"))
        let token = try XCTUnwrap(Data(base64URLEncoded: payload.token))
        let deviceId = "phone-" + Crypto.randomBytes(9).base64URLEncodedString()
        let c = Client.connect(port: payload.port)
        let sn = try XCTUnwrap(try await c.receive()["serverNonce"] as? String)
        let cn = Crypto.randomBytes(16).base64URLEncodedString()
        try await c.send(["type": "pair_request", "deviceId": deviceId, "deviceName": "Test phone", "clientNonce": cn,
                          "proof": Handshake.pairProof(token: token, deviceId: deviceId, clientNonce: cn, serverNonce: sn).base64URLEncodedString()])
        XCTAssertEqual(try await c.receive()["type"] as? String, "pair_pending")
        XCTAssertEqual(try await c.receive()["reason"] as? String, "declined")
        XCTAssertTrue(server.pairedDevices.isEmpty)
    }
}
#endif
