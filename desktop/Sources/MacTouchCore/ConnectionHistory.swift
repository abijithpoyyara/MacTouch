import Foundation

public enum HistoryKind: String, Codable, CaseIterable {
    case serverStarted, serverStopped, serverFailed, paired, declined, connected, disconnected

    public var title: String {
        switch self {
        case .serverStarted: return "Server started"
        case .serverStopped: return "Server stopped"
        case .serverFailed: return "Server problem"
        case .paired: return "Paired"
        case .declined: return "Pairing declined"
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        }
    }
}

public struct HistoryEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let kind: HistoryKind
    public let device: String?
    public let detail: String?

    public init(id: UUID = UUID(), date: Date = Date(), kind: HistoryKind, device: String? = nil, detail: String? = nil) {
        self.id = id; self.date = date; self.kind = kind; self.device = device; self.detail = detail
    }
}

/// A capped log of what happened on this Mac (newest first), kept in UserDefaults. Contains no keys or tokens.
public final class ConnectionHistoryStore {
    private let defaults: UserDefaults
    private let key = "mactouch.history.v1"
    private let limit: Int
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, limit: Int = 100) {
        self.defaults = defaults
        self.limit = max(1, limit)
    }

    public func all() -> [HistoryEntry] {
        lock.lock(); defer { lock.unlock() }
        return readLocked()
    }

    @discardableResult
    public func append(_ kind: HistoryKind, device: String? = nil, detail: String? = nil, date: Date = Date()) -> HistoryEntry {
        lock.lock(); defer { lock.unlock() }
        let entry = HistoryEntry(date: date, kind: kind, device: device.map { String($0.prefix(64)) }, detail: detail.map { String($0.prefix(200)) })
        writeLocked(Array(([entry] + readLocked()).prefix(limit)))
        return entry
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }

    private func readLocked() -> [HistoryEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        guard let list = try? dec.decode([HistoryEntry].self, from: data) else { return [] }   // corrupt data = empty log
        return list.sorted { $0.date > $1.date }
    }

    private func writeLocked(_ list: [HistoryEntry]) {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(list) { defaults.set(data, forKey: key) }
    }
}
