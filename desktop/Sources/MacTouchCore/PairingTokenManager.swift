import Foundation

/// Single-use, expiring pairing token shown in the QR code.
public final class PairingTokenManager {
    public struct Token {
        public let bytes: Data
        public let expiresAt: Date
        public var encoded: String { bytes.base64URLEncodedString() }
    }

    public enum ConsumeResult {
        case ok(Token)
        case expired
        case inUse
        case badProof
    }

    public static let maxFailedAttempts = 5

    private let ttl: TimeInterval
    private let now: () -> Date
    private let lock = NSLock()
    private var token: Token
    private var consumed = false
    private var failures = 0

    public init(ttl: TimeInterval = Proto.pairingTokenTTL, now: @escaping () -> Date = Date.init) {
        self.ttl = ttl
        self.now = now
        self.token = Token(bytes: Crypto.randomBytes(32), expiresAt: now().addingTimeInterval(ttl))
    }

    /// The token to show in the QR code, or nil while a pairing is in progress.
    public func activeToken() -> Token? {
        lock.lock(); defer { lock.unlock() }
        return (consumed || now() >= token.expiresAt) ? nil : token
    }

    public var expiresAt: Date { lock.lock(); defer { lock.unlock() }; return token.expiresAt }

    @discardableResult
    public func rotate() -> Token {
        lock.lock(); defer { lock.unlock() }
        return rotateLocked()
    }

    /// Rotates if the token expired (not while a pairing is in progress). Returns true when rotated.
    public func tickRotatingIfExpired() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !consumed, now() >= token.expiresAt else { return false }
        _ = rotateLocked()
        return true
    }

    /// Atomically verifies a proof against the current token and marks it used.
    public func verifyAndConsume(_ verify: (Data) -> Bool) -> ConsumeResult {
        lock.lock(); defer { lock.unlock() }
        if consumed { return .inUse }
        if now() >= token.expiresAt { _ = rotateLocked(); return .expired }
        guard verify(token.bytes) else {
            failures += 1
            if failures >= Self.maxFailedAttempts { _ = rotateLocked() }
            return .badProof
        }
        consumed = true
        return .ok(token)
    }

    private func rotateLocked() -> Token {
        token = Token(bytes: Crypto.randomBytes(32), expiresAt: now().addingTimeInterval(ttl))
        consumed = false
        failures = 0
        return token
    }
}
