import Foundation
import os

/// Logging that never sees secrets: callers pass identifiers through `Log.short`,
/// and tokens, secrets and proofs have no logging path at all.
public enum Log {
    private static let logger = Logger(subsystem: "app.mactouch.desktop", category: "core")

    public static func info(_ message: String) { logger.info("\(message, privacy: .public)") }
    public static func warn(_ message: String) { logger.warning("\(message, privacy: .public)") }
    public static func error(_ message: String) { logger.error("\(message, privacy: .public)") }

    /// "phone-0123456789abcdef" -> "phone-…cdef"
    public static func short(_ id: String) -> String {
        id.count <= 10 ? "…" + id.suffix(4) : String(id.prefix(6)) + "…" + id.suffix(4)
    }
}
