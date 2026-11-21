import Foundation

/// Wire-protocol constants. Keep in sync with protocol/PROTOCOL.md and mobile/lib/core/protocol.
public enum Proto {
    public static let version = 1
    public static let appId = "mactouch"
    public static let defaultPort: UInt16 = 48500
    public static let maxMessageBytes = 16 * 1024
    public static let pairingTokenTTL: TimeInterval = 120
    public static let handshakeTimeout: TimeInterval = 15
    public static let approvalTimeout: TimeInterval = 60
    public static let idleTimeout: TimeInterval = 30
}

public enum MsgType {
    public static let challenge = "challenge"
    public static let pairRequest = "pair_request"
    public static let pairPending = "pair_pending"
    public static let pairAccepted = "pair_accepted"
    public static let pairRejected = "pair_rejected"
    public static let auth = "auth"
    public static let authOK = "auth_ok"
    public static let authFailed = "auth_failed"
    public static let ping = "ping"
    public static let pong = "pong"
    public static let disconnect = "disconnect"
    public static let error = "error"
}

public enum Reason {
    public static let tokenExpired = "token_expired"
    public static let invalidProof = "invalid_proof"
    public static let declined = "declined"
    public static let busy = "busy"
    public static let timeout = "timeout"
    public static let unknownDevice = "unknown_device"
    public static let badMessage = "bad_message"
    public static let unauthenticated = "unauthenticated"
    public static let unsupported = "unsupported"
    public static let internalError = "internal_error"
}

/// JSON carried by the pairing QR code.
public struct QRPayload: Codable, Equatable {
    public let app: String
    public let v: Int
    public let host: String
    public let port: Int
    public let token: String   // base64url, 32 bytes
    public let exp: Int        // unix seconds
    public let name: String
    public let id: String      // stable desktop identity

    public func jsonString() throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try enc.encode(self), as: UTF8.self)
    }
}

public struct PairedDevice: Codable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public let pairedAt: Date
    public var lastSeen: Date?

    public init(id: String, name: String, pairedAt: Date = Date(), lastSeen: Date? = nil) {
        self.id = id; self.name = name; self.pairedAt = pairedAt; self.lastSeen = lastSeen
    }
}

public struct PairingRequest: Identifiable, Equatable {
    public let id: UUID
    public let deviceId: String
    public let deviceName: String
    public let remoteAddress: String
    public let receivedAt: Date
}

public enum Validation {
    private static let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    /// 8...64 chars of [A-Za-z0-9_-]. Used for device ids and nonces.
    public static func isValidId(_ s: String) -> Bool {
        (8...64).contains(s.count) && s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
