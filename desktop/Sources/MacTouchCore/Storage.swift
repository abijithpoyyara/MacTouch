import Foundation
import Security

public protocol SecretStore: AnyObject {
    func save(_ secret: Data, for deviceId: String) throws
    func load(for deviceId: String) -> Data?
    func delete(for deviceId: String)
}

public struct KeychainError: Error, CustomStringConvertible {
    public let status: OSStatus
    public var description: String { "Keychain error \(status)" }
}

/// Long-term device secrets live in the macOS Keychain, never in UserDefaults or files.
public final class KeychainSecretStore: SecretStore {
    private let service: String
    public init(service: String = "app.mactouch.desktop.device-secrets") { self.service = service }

    private func query(_ id: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: id]
    }

    public func save(_ secret: Data, for deviceId: String) throws {
        delete(for: deviceId)
        var q = query(deviceId)
        q[kSecValueData as String] = secret
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func load(for deviceId: String) -> Data? {
        var q = query(deviceId)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    public func delete(for deviceId: String) {
        SecItemDelete(query(deviceId) as CFDictionary)
    }
}

/// For tests only.
public final class InMemorySecretStore: SecretStore {
    private var items: [String: Data] = [:]
    private let lock = NSLock()
    public init() {}
    public func save(_ secret: Data, for deviceId: String) throws { lock.lock(); items[deviceId] = secret; lock.unlock() }
    public func load(for deviceId: String) -> Data? { lock.lock(); defer { lock.unlock() }; return items[deviceId] }
    public func delete(for deviceId: String) { lock.lock(); items[deviceId] = nil; lock.unlock() }
}

/// Non-secret metadata (name, dates) about paired phones.
public final class PairedDeviceStore {
    private let defaults: UserDefaults
    private let key = "mactouch.pairedDevices.v1"
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func all() -> [PairedDevice] {
        lock.lock(); defer { lock.unlock() }
        return readLocked()
    }

    public func find(id: String) -> PairedDevice? { all().first { $0.id == id } }

    public func upsert(_ device: PairedDevice) {
        lock.lock(); defer { lock.unlock() }
        var list = readLocked().filter { $0.id != device.id }
        list.append(device)
        writeLocked(list)
    }

    public func remove(id: String) {
        lock.lock(); defer { lock.unlock() }
        writeLocked(readLocked().filter { $0.id != id })
    }

    private func readLocked() -> [PairedDevice] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode([PairedDevice].self, from: data)) ?? []
    }

    private func writeLocked(_ list: [PairedDevice]) {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(list) { defaults.set(data, forKey: key) }
    }
}
