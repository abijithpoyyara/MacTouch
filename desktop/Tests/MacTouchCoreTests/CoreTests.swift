#if canImport(XCTest)
import XCTest
@testable import MacTouchCore

private struct Vectors: Decodable {
    let token, deviceId, clientNonce, serverNonce, pairProof, secret, authProof, serverProof: String
}

private func loadVectors() throws -> Vectors {
    // .../MacTouch/desktop/Tests/MacTouchCoreTests/CoreTests.swift -> .../MacTouch/protocol/test-vectors.json
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { url.deleteLastPathComponent() }
    url.appendPathComponent("protocol/test-vectors.json")
    return try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url))
}

final class CoreTests: XCTestCase {
    func testHandshakeMatchesSharedVectors() throws {
        let v = try loadVectors()
        let token = try XCTUnwrap(Data(base64URLEncoded: v.token))
        XCTAssertEqual(Handshake.pairProof(token: token, deviceId: v.deviceId, clientNonce: v.clientNonce, serverNonce: v.serverNonce).base64URLEncodedString(), v.pairProof)
        let secret = Handshake.deriveSecret(token: token, deviceId: v.deviceId, clientNonce: v.clientNonce, serverNonce: v.serverNonce)
        XCTAssertEqual(secret.base64URLEncodedString(), v.secret)
        XCTAssertEqual(Handshake.authProof(secret: secret, deviceId: v.deviceId, clientNonce: v.clientNonce, serverNonce: v.serverNonce).base64URLEncodedString(), v.authProof)
        XCTAssertEqual(Handshake.serverProof(secret: secret, clientNonce: v.clientNonce, serverNonce: v.serverNonce).base64URLEncodedString(), v.serverProof)
    }

    func testBase64URLRoundTrip() {
        for n in 0..<40 {
            let data = Crypto.randomBytes(n)
            let text = data.base64URLEncodedString()
            XCTAssertFalse(text.contains("=") || text.contains("+") || text.contains("/"))
            XCTAssertEqual(Data(base64URLEncoded: text), data)
        }
    }

    func testConstantTimeEqual() {
        XCTAssertTrue(Crypto.constantTimeEqual(Data([1, 2, 3]), Data([1, 2, 3])))
        XCTAssertFalse(Crypto.constantTimeEqual(Data([1, 2, 3]), Data([1, 2, 4])))
        XCTAssertFalse(Crypto.constantTimeEqual(Data([1, 2]), Data([1, 2, 3])))
    }

    func testTokenExpiresAndIsSingleUse() {
        var now = Date(timeIntervalSince1970: 1_000)
        let tokens = PairingTokenManager(ttl: 60, now: { now })
        XCTAssertNotNil(tokens.activeToken())

        guard case .ok = tokens.verifyAndConsume({ _ in true }) else { return XCTFail("first use should succeed") }
        guard case .inUse = tokens.verifyAndConsume({ _ in true }) else { return XCTFail("second use must be refused") }
        XCTAssertNil(tokens.activeToken(), "QR must be hidden while a pairing is in progress")

        tokens.rotate()
        XCTAssertNotNil(tokens.activeToken())
        now = now.addingTimeInterval(61)
        XCTAssertNil(tokens.activeToken())
        guard case .expired = tokens.verifyAndConsume({ _ in true }) else { return XCTFail("expired token must be refused") }
    }

    func testFiveBadProofsRotateTheToken() {
        let tokens = PairingTokenManager(ttl: 60)
        let before = tokens.activeToken()?.encoded
        for _ in 0..<PairingTokenManager.maxFailedAttempts {
            guard case .badProof = tokens.verifyAndConsume({ _ in false }) else { return XCTFail() }
        }
        XCTAssertNotEqual(tokens.activeToken()?.encoded, before)
    }

    func testPrivateIPv4Detection() {
        for ip in ["10.0.0.5", "172.16.1.1", "172.31.255.1", "192.168.1.20", "169.254.3.4"] { XCTAssertTrue(NetworkInfo.isPrivateIPv4(ip), ip) }
        for ip in ["8.8.8.8", "172.32.0.1", "192.169.0.1", "256.1.1.1", "abc", "1.2.3"] { XCTAssertFalse(NetworkInfo.isPrivateIPv4(ip), ip) }
    }

    func testIdValidation() {
        XCTAssertTrue(Validation.isValidId("phone-0123456789abcdef"))
        XCTAssertFalse(Validation.isValidId("short"))
        XCTAssertFalse(Validation.isValidId("has space in it!"))
        XCTAssertFalse(Validation.isValidId(String(repeating: "a", count: 65)))
    }

    func testQRPayloadJSON() throws {
        let p = QRPayload(app: "mactouch", v: 1, host: "192.168.1.20", port: 48500, token: "abc", exp: 1_700_000_000, name: "Mac mini", id: "server-1")
        let obj = try JSONSerialization.jsonObject(with: Data(p.jsonString().utf8)) as? [String: Any]
        XCTAssertEqual(obj?["app"] as? String, "mactouch")
        XCTAssertEqual(obj?["v"] as? Int, 1)
        XCTAssertEqual(obj?["port"] as? Int, 48500)
    }

    func testPairedDeviceStore() {
        let suite = UserDefaults(suiteName: "mactouch.tests.\(UUID().uuidString)")!
        let store = PairedDeviceStore(defaults: suite)
        store.upsert(PairedDevice(id: "dev-aaaaaaaa", name: "Pixel"))
        store.upsert(PairedDevice(id: "dev-aaaaaaaa", name: "Pixel 8"))
        XCTAssertEqual(store.all().count, 1)
        XCTAssertEqual(store.find(id: "dev-aaaaaaaa")?.name, "Pixel 8")
        store.remove(id: "dev-aaaaaaaa")
        XCTAssertTrue(store.all().isEmpty)
    }
}
#endif
