import Foundation
import CryptoKit
import Security

public extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded s: String) {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        b += String(repeating: "=", count: (4 - b.count % 4) % 4)
        self.init(base64Encoded: b)
    }
}

public enum Crypto {
    public static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return Data(bytes)
    }

    public static func hmac(key: Data, message: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: key)))
    }

    /// Constant-time comparison; different lengths compare unequal.
    public static func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a, b) { diff |= x ^ y }
        return diff == 0
    }
}

/// Handshake derivations. Domain-separated HMAC-SHA256; see protocol/PROTOCOL.md.
public enum Handshake {
    public static func pairProof(token: Data, deviceId: String, clientNonce: String, serverNonce: String) -> Data {
        Crypto.hmac(key: token, message: "pair|\(deviceId)|\(clientNonce)|\(serverNonce)")
    }
    public static func deriveSecret(token: Data, deviceId: String, clientNonce: String, serverNonce: String) -> Data {
        Crypto.hmac(key: token, message: "secret|\(deviceId)|\(clientNonce)|\(serverNonce)")
    }
    public static func authProof(secret: Data, deviceId: String, clientNonce: String, serverNonce: String) -> Data {
        Crypto.hmac(key: secret, message: "auth|\(deviceId)|\(clientNonce)|\(serverNonce)")
    }
    public static func serverProof(secret: Data, clientNonce: String, serverNonce: String) -> Data {
        Crypto.hmac(key: secret, message: "server|\(serverNonce)|\(clientNonce)")
    }
}
