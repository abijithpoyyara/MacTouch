import SwiftUI
import Network
import ServiceManagement
import MacTouchCore

/// Glue between the server and the UI. Views read this; they never touch the network code.
final class AppModel: ObservableObject, MacTouchServerDelegate {
    enum Status: Equatable { case stopped, starting, running, failed(String) }

    /// Something the user can fix, with a plain-language explanation.
    enum Issue: Equatable {
        case serverFailed(String)
        case noNetwork
        case accessibilityMissing
    }

    @Published var status: Status = .stopped
    @Published var qrImage: NSImage?
    @Published var qrExpiresAt: Date?
    @Published var localIP: String?
    @Published var port: UInt16 = Proto.defaultPort
    @Published var connectedDevice: PairedDevice?
    @Published var pending: PairingRequest?
    @Published var pairedDevices: [PairedDevice] = []
    @Published var accessibilityGranted = AccessibilityPermission.isGranted
    @Published var networkAvailable = true
    @Published var history: [HistoryEntry] = []
    @Published var launchAtLoginMessage: String?

    // Preferences (saved in UserDefaults, applied immediately)
    @Published var deviceName: String { didSet { saveDeviceName() } }
    @Published var autoStartServer: Bool { didSet { defaults.set(autoStartServer, forKey: Keys.autoStart) } }
    @Published var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Keys.menuBar) } }
    @Published var showDockIcon: Bool {
        didSet { defaults.set(showDockIcon, forKey: Keys.dock); applyActivationPolicy() }
    }
    @Published var launchAtLogin: Bool

    private enum Keys {
        static let serverId = "mactouch.serverId"
        static let name = "mactouch.deviceName"
        static let autoStart = "mactouch.autoStart"
        static let menuBar = "mactouch.menuBarIcon"
        static let dock = "mactouch.dockIcon"
    }

    private let defaults = UserDefaults.standard
    private let server: MacTouchServer
    private let historyStore = ConnectionHistoryStore()
    private var respondHandler: ((Bool) -> Void)?
    private var alertActive = false
    private let monitor = NWPathMonitor()
    private var accessibilityTimer: Timer?
    private var lastStatus: Status = .stopped

    init() {
        let serverId = defaults.string(forKey: Keys.serverId) ?? Crypto.randomBytes(12).base64URLEncodedString()
        defaults.set(serverId, forKey: Keys.serverId)

        let fallbackName = String((Host.current().localizedName ?? ProcessInfo.processInfo.hostName).prefix(64))
        let name = defaults.string(forKey: Keys.name).flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? fallbackName
        deviceName = name
        autoStartServer = defaults.object(forKey: Keys.autoStart) as? Bool ?? true
        showMenuBarIcon = defaults.object(forKey: Keys.menuBar) as? Bool ?? true
        showDockIcon = defaults.object(forKey: Keys.dock) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled

        server = MacTouchServer(serverName: name, serverId: serverId, secrets: KeychainSecretStore(), devices: PairedDeviceStore())
        server.delegate = self
        pairedDevices = server.pairedDevices.sorted { $0.pairedAt > $1.pairedAt }
        history = historyStore.all()

        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkAvailable = path.status == .satisfied
                self?.refreshQR()
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.mactouch.pathmonitor"))

        // Cheap permission poll; the setting can change at any time while the app runs.
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = AccessibilityPermission.isGranted
            if granted != self.accessibilityGranted { self.accessibilityGranted = granted }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.server.stopSync() }
        if autoStartServer { server.start() }
    }

    // MARK: Derived text, shared by the window, the menu bar and the pairing window

    var issues: [Issue] {
        var list: [Issue] = []
        if case .failed(let message) = status { list.append(.serverFailed(message)) }
        if status == .running && (!networkAvailable || localIP == nil) { list.append(.noNetwork) }
        if !accessibilityGranted { list.append(.accessibilityMissing) }
        return list
    }

    var headline: String {
        if let d = connectedDevice { return "Connected to \(d.name)" }
        if pending != nil { return "Pairing request" }
        switch status {
        case .running: return "Waiting for a phone"
        case .starting: return "Starting\u{2026}"
        case .stopped: return "Server is stopped"
        case .failed: return "Server could not start"
        }
    }

    var subheadline: String {
        if connectedDevice != nil {
            return accessibilityGranted ? "Your phone is controlling this Mac." : "Allow Accessibility so your phone can move the pointer."
        }
        switch status {
        case .running: return localIP.map { "Listening on \($0):\(port)" } ?? "No local network address"
        case .failed(let message): return message
        case .stopped: return "Start the server to pair or reconnect a phone."
        case .starting: return "Opening the network port."
        }
    }

    var menuSymbol: String {
        if connectedDevice != nil { return "hand.point.up.left.fill" }
        switch status {
        case .failed: return "exclamationmark.triangle.fill"
        case .stopped: return "hand.point.up.left"
        default: return accessibilityGranted ? "hand.point.up.left" : "exclamationmark.circle"
        }
    }

    var isRunning: Bool { if case .running = status { return true } else { return false } }

    // MARK: Intents

    func startServer() { server.start() }
    func stopServer() { server.stop() }

    func restartServer() {
        server.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.server.start() }
    }

    func disconnectDevice() { server.disconnectActiveDevice() }

    func forget(_ device: PairedDevice) {
        server.forget(deviceId: device.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.reloadDevices() }
    }

    func requestAccessibility() { AccessibilityPermission.requestPrompt(); AccessibilityPermission.openSettings() }
    func recheckAccessibility() { accessibilityGranted = AccessibilityPermission.isGranted }

    func clearHistory() { historyStore.clear(); history = [] }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginMessage = nil
        } catch {
            launchAtLoginMessage = "macOS did not allow this: \(error.localizedDescription) Run MacTouch from the Applications folder and try again."
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func respond(_ approve: Bool) {
        let handler = respondHandler
        let request = pending
        respondHandler = nil
        pending = nil
        handler?(approve)
        if let request { record(approve ? .paired : .declined, device: request.deviceName, detail: "from \(request.remoteAddress)") }
        if approve { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.reloadDevices() } }
    }

    // MARK: Helpers

    private func saveDeviceName() {
        let trimmed = String(deviceName.trimmingCharacters(in: .whitespaces).prefix(64))
        guard !trimmed.isEmpty else { return }
        defaults.set(trimmed, forKey: Keys.name)
        server.serverName = trimmed
        refreshQR()
    }

    private func applyActivationPolicy() {
        NSApp?.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    private func reloadDevices() { pairedDevices = server.pairedDevices.sorted { $0.pairedAt > $1.pairedAt } }

    private func record(_ kind: HistoryKind, device: String? = nil, detail: String? = nil) {
        historyStore.append(kind, device: device, detail: detail)
        history = historyStore.all()
    }

    func refreshQR() {
        localIP = NetworkInfo.primaryAddress()
        port = server.port == 0 ? port : server.port
        guard status == .running, let ip = localIP, let payload = server.qrPayload(host: ip),
              let json = try? payload.jsonString() else {
            qrImage = nil; qrExpiresAt = nil; return
        }
        qrImage = QRCode.image(from: json, points: 300)
        qrExpiresAt = Date(timeIntervalSince1970: TimeInterval(payload.exp))
    }

    /// The native confirmation. Runs outside the delegate callback, and is dismissed if the request times out.
    private func presentPairingAlert(for request: PairingRequest) {
        guard pending?.id == request.id, !alertActive else { return }
        alertActive = true
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Pair \u{201C}\(request.deviceName)\u{201D}?"
        alert.informativeText = "This phone wants to control this Mac's pointer. Only approve if you just scanned this code yourself.\n\nAddress: \(request.remoteAddress)"
        alert.addButton(withTitle: "Pair")
        alert.addButton(withTitle: "Decline")
        let response = alert.runModal()
        alertActive = false
        guard pending?.id == request.id else { return }       // already ended (for example it timed out)
        respond(response == .alertFirstButtonReturn)
    }

    // MARK: MacTouchServerDelegate (main queue)

    func server(_ server: MacTouchServer, didChangeState state: MacTouchServer.State) {
        let next: Status
        switch state {
        case .stopped: next = .stopped; connectedDevice = nil; pending = nil; respondHandler = nil
        case .starting: next = .starting
        case .running: next = .running
        case .failed(let message): next = .failed(message)
        }
        if next != lastStatus {
            switch next {
            case .running: record(.serverStarted, detail: "port \(server.port == 0 ? port : server.port)")
            case .stopped: if lastStatus != .starting { record(.serverStopped) }
            case .failed(let message): record(.serverFailed, detail: message)
            case .starting: break
            }
            lastStatus = next
        }
        status = next
        refreshQR()
    }

    func server(_ server: MacTouchServer, didReceivePairingRequest request: PairingRequest, respond: @escaping (Bool) -> Void) {
        pending = request
        respondHandler = respond
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in self?.presentPairingAlert(for: request) }
    }

    func server(_ server: MacTouchServer, pairingRequestEnded id: UUID) {
        guard pending?.id == id else { return }
        pending = nil
        respondHandler = nil
        if alertActive { NSApp.abortModal() }
    }

    func server(_ server: MacTouchServer, didAuthenticate device: PairedDevice) {
        connectedDevice = device
        reloadDevices()
        record(.connected, device: device.name)
    }

    func server(_ server: MacTouchServer, didDisconnect device: PairedDevice) {
        guard connectedDevice?.id == device.id else { return }
        connectedDevice = nil
        record(.disconnected, device: device.name)
    }

    func serverDidRotatePairingToken(_ server: MacTouchServer) { refreshQR() }
}
