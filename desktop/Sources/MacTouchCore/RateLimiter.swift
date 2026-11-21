import Foundation

/// Token bucket. Defaults allow bursts of 400 frames and 250 frames/s sustained
/// (the phone sends about 125/s at most).
public struct RateLimiter {
    private let capacity: Double
    private let refillPerSecond: Double
    private var tokens: Double
    private var last: TimeInterval
    private let now: () -> TimeInterval

    public init(capacity: Double = 400, refillPerSecond: Double = 250,
                now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.capacity = capacity
        self.refillPerSecond = refillPerSecond
        self.now = now
        self.tokens = capacity
        self.last = now()
    }

    public mutating func allow() -> Bool {
        let t = now()
        tokens = min(capacity, tokens + max(0, t - last) * refillPerSecond)
        last = t
        guard tokens >= 1 else { return false }
        tokens -= 1
        return true
    }
}
