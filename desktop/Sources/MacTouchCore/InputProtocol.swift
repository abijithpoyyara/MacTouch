import Foundation

// Part 2: signed input frames. See protocol/INPUT.md.

public extension MsgType {
    static let input = "input"
    static let status = "status"
}

public extension Reason {
    static let badMac = "bad_mac"
    static let badSeq = "bad_sequence"
    static let rateLimited = "rate_limited"
    static let invalidCommand = "invalid_command"
}

public enum InputLimits {
    public static let maxBodyBytes = 4096
    public static let maxEventsPerFrame = 64
    public static let maxMoveDelta = 2000
    public static let maxScrollDelta = 1000
    public static let maxKeyCode = 255
    /// Consecutive rate-limited frames (~2 s of flooding) before the session is closed.
    public static let maxDropStreak = 400
}

public extension Handshake {
    /// Per-session key for authenticating input frames. Never sent over the wire.
    static func sessionKey(secret: Data, clientNonce: String, serverNonce: String) -> Data {
        Crypto.hmac(key: secret, message: "session|\(clientNonce)|\(serverNonce)")
    }

    /// MAC over the exact UTF-8 `body` string of an input frame; `seq` makes replays detectable.
    static func inputMac(key: Data, seq: Int, body: String) -> Data {
        Crypto.hmac(key: key, message: "input|\(seq)|\(body)")
    }
}
