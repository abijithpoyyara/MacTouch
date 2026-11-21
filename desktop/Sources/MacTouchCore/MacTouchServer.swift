import Foundation
import Network

/// All delegate callbacks are delivered on the main queue.
public protocol MacTouchServerDelegate: AnyObject {
    func server(_ server: MacTouchServer, didChangeState state: MacTouchServer.State)
    /// Call `respond(true)` to approve or `respond(false)` to decline. Safe to call more than once.
    func server(_ server: MacTouchServer, didReceivePairingRequest request: PairingRequest, respond: @escaping (Bool) -> Void)
    func server(_ server: MacTouchServer, pairingRequestEnded id: UUID)
    func server(_ server: MacTouchServer, didAuthenticate device: PairedDevice)
    func server(_ server: MacTouchServer, didDisconnect device: PairedDevice)
    func serverDidRotatePairingToken(_ server: MacTouchServer)
}

public final class MacTouchServer {
    public enum State: Equatable {
        case stopped
        case starting
        case running(port: UInt16)
        case failed(String)
    }

    private final class Session {
        enum Stage { case handshake, pairing, authenticated, closed }
        let id = UUID()
        let connection: NWConnection
        let serverNonce = Crypto.randomBytes(16).base64URLEncodedString()
        let remote: String
        var stage: Stage = .handshake
        var deviceId: String?
        var requestId: UUID?
        var holdsToken = false
        var timeout: DispatchWorkItem?
        var lastActivity = Date()
        // Part 2: signed input frames
        var sessionKey: Data?
        var lastSeq = 0
        var limiter = RateLimiter()
        var dropStreak = 0
        var lastTrusted: Bool?

        init(connection: NWConnection) {
            self.connection = connection
            if case let .hostPort(host, _) = connection.endpoint {
                remote = "\(host)".split(separator: "%").first.map(String.init) ?? "unknown"
            } else {
                remote = "unknown"
            }
        }
    }

    public weak var delegate: MacTouchServerDelegate?
    public let serverId: String
    public var serverName: String

    private let preferredPort: UInt16
    private let secrets: SecretStore
    private let devices: PairedDeviceStore
    private let tokens: PairingTokenManager
    private let input: InputEngine
    private let queue = DispatchQueue(label: "app.mactouch.server")

    private var listener: NWListener?
    private var sessions: [UUID: Session] = [:]
    private var active: Session?
    private var housekeeping: DispatchSourceTimer?
    private let portLock = NSLock()
    private var _port: UInt16 = 0

    public init(serverName: String, serverId: String, secrets: SecretStore, devices: PairedDeviceStore,
                tokens: PairingTokenManager = PairingTokenManager(), port: UInt16 = Proto.defaultPort,
                input: InputEngine = InputEngine(poster: CGEventPoster())) {
        self.serverName = serverName
        self.serverId = serverId
        self.secrets = secrets
        self.devices = devices
        self.tokens = tokens
        self.preferredPort = port
        self.input = input
    }

    // MARK: Public API (thread-safe)

    public var port: UInt16 { portLock.lock(); defer { portLock.unlock() }; return _port }
    public var pairedDevices: [PairedDevice] { devices.all() }
    public var tokenExpiresAt: Date { tokens.expiresAt }

    /// nil while stopped, or while another phone is mid-pairing.
    public func qrPayload(host: String) -> QRPayload? {
        guard port != 0, let token = tokens.activeToken() else { return nil }
        return QRPayload(app: Proto.appId, v: Proto.version, host: host, port: Int(port),
                         token: token.encoded, exp: Int(token.expiresAt.timeIntervalSince1970),
                         name: serverName, id: serverId)
    }

    public func start() { queue.async { self.startLocked() } }
    public func stop() { queue.async { self.stopLocked() } }

    /// Stops and waits, so every button and key is released before the app exits. Never call on the server queue.
    public func stopSync() { queue.sync { self.stopLocked() } }

    /// Whether macOS currently lets this app post input events.
    public var accessibilityTrusted: Bool { input.isTrusted }
    public func disconnectActiveDevice() { queue.async { if let a = self.active { self.close(a, notify: true) } } }

    public func forget(deviceId: String) {
        queue.async {
            if let a = self.active, a.deviceId == deviceId { self.close(a, notify: true) }
            self.secrets.delete(for: deviceId)
            self.devices.remove(id: deviceId)
        }
    }

    // MARK: Lifecycle

    private func startLocked() {
        guard listener == nil else { return }
        setState(.starting)
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        ws.maximumMessageSize = Proto.maxMessageBytes
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)

        do {
            guard let nwPort = NWEndpoint.Port(rawValue: preferredPort) else { throw NWError.posix(.EINVAL) }
            let l = try NWListener(using: params, on: nwPort)
            l.stateUpdateHandler = { [weak self, weak l] state in
                guard let self, let l, self.listener === l else { return }
                switch state {
                case .ready:
                    let p = l.port?.rawValue ?? self.preferredPort
                    self.portLock.lock(); self._port = p; self.portLock.unlock()
                    self.setState(.running(port: p))
                case .failed(let error):
                    Log.error("Listener failed: \(error)")
                    self.stopLocked()
                    let hint = (error == .posix(.EADDRINUSE)) ? "Port \(self.preferredPort) is already in use." : "\(error)"
                    self.setState(.failed(hint))
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            listener = l
            startHousekeeping()
            l.start(queue: queue)
        } catch {
            Log.error("Could not create listener: \(error)")
            setState(.failed("\(error)"))
        }
    }

    private func stopLocked() {
        let l = listener
        listener = nil
        housekeeping?.cancel(); housekeeping = nil
        for s in Array(sessions.values) { close(s, notify: true) }
        l?.cancel()
        portLock.lock(); _port = 0; portLock.unlock()
        setState(.stopped)
    }

    private func startHousekeeping() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            if self.tokens.tickRotatingIfExpired() { self.onMain { $0.serverDidRotatePairingToken(self) } }
            let cutoff = Date().addingTimeInterval(-Proto.idleTimeout)
            for s in Array(self.sessions.values) where s.stage == .authenticated && s.lastActivity < cutoff {
                Log.info("Idle timeout for \(Log.short(s.deviceId ?? "?"))")
                self.close(s, notify: true)
            }
            self.pushStatusIfChanged()
        }
        t.resume()
        housekeeping = t
    }

    // MARK: Connections

    private func accept(_ connection: NWConnection) {
        guard sessions.count < 8 else { connection.cancel(); return }
        let s = Session(connection: connection)
        sessions[s.id] = s
        connection.stateUpdateHandler = { [weak self, weak s] state in
            guard let self, let s else { return }
            switch state {
            case .ready:
                self.send(s, [ "type": MsgType.challenge, "serverNonce": s.serverNonce,
                               "serverId": self.serverId, "serverName": self.serverName ])
                self.armTimeout(s, after: Proto.handshakeTimeout, reason: Reason.timeout)
                self.receive(s)
            case .failed, .cancelled:
                self.close(s, notify: true, sendCloseFrame: false)
            default: break
            }
        }
        connection.start(queue: queue)
    }

    private func receive(_ s: Session) {
        s.connection.receiveMessage { [weak self, weak s] data, context, _, error in
            guard let self, let s, s.stage != .closed else { return }
            if error != nil { self.close(s, notify: true, sendCloseFrame: false); return }
            if let meta = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {
                switch meta.opcode {
                case .text:
                    if let data { self.handle(s, data) }
                case .close:
                    self.close(s, notify: true, sendCloseFrame: false); return
                default: break   // binary and control frames are ignored
                }
            }
            if s.stage != .closed { self.receive(s) }
        }
    }

    private func send(_ s: Session, _ fields: [String: Any]) {
        var body = fields
        body["v"] = Proto.version
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let ctx = NWConnection.ContentContext(identifier: "text", metadata: [meta])
        s.connection.send(content: data, contentContext: ctx, isComplete: true, completion: .contentProcessed { _ in })
    }

    private func armTimeout(_ s: Session, after seconds: TimeInterval, reason: String) {
        s.timeout?.cancel()
        let work = DispatchWorkItem { [weak self, weak s] in
            guard let self, let s, s.stage == .handshake || s.stage == .pairing else { return }
            Log.info("Session timed out (\(reason))")
            self.reject(s, type: s.stage == .pairing ? MsgType.pairRejected : MsgType.error, reason: reason)
        }
        s.timeout = work
        queue.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    /// Sends a terminal message, then closes.
    private func reject(_ s: Session, type: String, reason: String) {
        send(s, ["type": type, "reason": reason])
        close(s, notify: true)
    }

    private func close(_ s: Session, notify: Bool, sendCloseFrame: Bool = true) {
        guard s.stage != .closed else { return }
        let wasActive = (active === s)
        s.stage = .closed
        s.timeout?.cancel()
        sessions[s.id] = nil
        if wasActive { active = nil; input.releaseAll() }   // nothing may stay pressed after a session ends

        if sendCloseFrame {
            let meta = NWProtocolWebSocket.Metadata(opcode: .close)
            meta.closeCode = .protocolCode(.normalClosure)
            let ctx = NWConnection.ContentContext(identifier: "close", metadata: [meta])
            s.connection.send(content: nil, contentContext: ctx, isComplete: true,
                              completion: .contentProcessed { [weak s] _ in s?.connection.cancel() })
        } else {
            s.connection.cancel()
        }
        endPairing(s)
        if wasActive, notify, let id = s.deviceId {
            let device = devices.find(id: id) ?? PairedDevice(id: id, name: "Device")
            Log.info("Device disconnected: \(Log.short(id))")
            onMain { $0.server(self, didDisconnect: device) }
        }
    }

    /// Called when a session that consumed the pairing token is done with it.
    private func endPairing(_ s: Session) {
        if let request = s.requestId {
            s.requestId = nil
            onMain { $0.server(self, pairingRequestEnded: request) }
        }
        if s.holdsToken {
            s.holdsToken = false
            tokens.rotate()
            onMain { $0.serverDidRotatePairingToken(self) }
        }
    }

    // MARK: Message handling

    private func handle(_ s: Session, _ data: Data) {
        guard data.count <= Proto.maxMessageBytes,
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = obj["type"] as? String else {
            reject(s, type: MsgType.error, reason: Reason.badMessage); return
        }
        s.lastActivity = Date()

        switch (s.stage, type) {
        case (.authenticated, MsgType.ping):
            var pong: [String: Any] = ["type": MsgType.pong]
            if let t = InputParser.int(obj["t"]) { pong["t"] = t }   // lets the phone measure latency
            send(s, pong)
        case (.authenticated, MsgType.disconnect):
            close(s, notify: true)
        case (.authenticated, MsgType.input):
            handleInput(s, obj)
        case (.authenticated, _):
            // Unknown message types are refused; the session stays up.
            send(s, ["type": MsgType.error, "code": Reason.unsupported])
        case (.handshake, MsgType.pairRequest):
            handlePairRequest(s, obj)
        case (.handshake, MsgType.auth):
            handleAuth(s, obj)
        case (.pairing, _):
            break   // waiting for the user; ignore chatter
        default:
            reject(s, type: MsgType.error, reason: Reason.unauthenticated)
        }
    }

    private struct Credentials { let deviceId: String; let clientNonce: String; let proof: Data }

    private func credentials(_ obj: [String: Any]) -> Credentials? {
        guard let id = obj["deviceId"] as? String, Validation.isValidId(id),
              let nonce = obj["clientNonce"] as? String, Validation.isValidId(nonce),
              let proofText = obj["proof"] as? String, let proof = Data(base64URLEncoded: proofText) else { return nil }
        return Credentials(deviceId: id, clientNonce: nonce, proof: proof)
    }

    private func handlePairRequest(_ s: Session, _ obj: [String: Any]) {
        guard let c = credentials(obj),
              let rawName = obj["deviceName"] as? String else {
            reject(s, type: MsgType.pairRejected, reason: Reason.badMessage); return
        }
        let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(64))
        guard !name.isEmpty else { reject(s, type: MsgType.pairRejected, reason: Reason.badMessage); return }

        if active != nil || sessions.values.contains(where: { $0.stage == .pairing }) {
            reject(s, type: MsgType.pairRejected, reason: Reason.busy); return
        }

        let result = tokens.verifyAndConsume { tokenBytes in
            let expected = Handshake.pairProof(token: tokenBytes, deviceId: c.deviceId,
                                               clientNonce: c.clientNonce, serverNonce: s.serverNonce)
            return Crypto.constantTimeEqual(expected, c.proof)
        }

        switch result {
        case .expired:
            onMain { $0.serverDidRotatePairingToken(self) }
            reject(s, type: MsgType.pairRejected, reason: Reason.tokenExpired)
        case .inUse:
            reject(s, type: MsgType.pairRejected, reason: Reason.busy)
        case .badProof:
            Log.warn("Pairing attempt with invalid proof from \(s.remote)")
            reject(s, type: MsgType.pairRejected, reason: Reason.invalidProof)
        case .ok(let token):
            s.stage = .pairing
            s.deviceId = c.deviceId
            s.holdsToken = true
            let request = PairingRequest(id: UUID(), deviceId: c.deviceId, deviceName: name,
                                         remoteAddress: s.remote, receivedAt: Date())
            s.requestId = request.id
            let secret = Handshake.deriveSecret(token: token.bytes, deviceId: c.deviceId,
                                                clientNonce: c.clientNonce, serverNonce: s.serverNonce)
            armTimeout(s, after: Proto.approvalTimeout, reason: Reason.timeout)
            send(s, ["type": MsgType.pairPending])
            onMain { [weak self] delegate in
                guard let self else { return }
                delegate.server(self, didReceivePairingRequest: request) { [weak self] approved in
                    self?.queue.async {
                        self?.finishPairing(s, requestId: request.id, name: name, secret: secret,
                                            clientNonce: c.clientNonce, approved: approved)
                    }
                }
            }
            onMain { $0.serverDidRotatePairingToken(self) }   // QR now shows "pairing in progress"
        }
    }

    private func finishPairing(_ s: Session, requestId: UUID, name: String, secret: Data,
                               clientNonce: String, approved: Bool) {
        guard s.stage == .pairing, s.requestId == requestId, let deviceId = s.deviceId else { return }
        guard approved else { reject(s, type: MsgType.pairRejected, reason: Reason.declined); return }
        do { try secrets.save(secret, for: deviceId) } catch {
            Log.error("Could not store device secret: \(error)")
            reject(s, type: MsgType.pairRejected, reason: Reason.internalError); return
        }
        let device = PairedDevice(id: deviceId, name: name, pairedAt: Date(), lastSeen: Date())
        devices.upsert(device)
        s.timeout?.cancel()
        let proof = Handshake.serverProof(secret: secret, clientNonce: clientNonce, serverNonce: s.serverNonce)
        s.sessionKey = Handshake.sessionKey(secret: secret, clientNonce: clientNonce, serverNonce: s.serverNonce)
        send(s, ["type": MsgType.pairAccepted, "serverProof": proof.base64URLEncodedString(),
                 "accessibility": input.isTrusted])
        promote(s, device: device)
        endPairing(s)
        Log.info("Paired with \(Log.short(deviceId))")
    }

    private func handleAuth(_ s: Session, _ obj: [String: Any]) {
        guard let c = credentials(obj) else { reject(s, type: MsgType.authFailed, reason: Reason.badMessage); return }
        guard let secret = secrets.load(for: c.deviceId), var device = devices.find(id: c.deviceId) else {
            reject(s, type: MsgType.authFailed, reason: Reason.unknownDevice); return
        }
        let expected = Handshake.authProof(secret: secret, deviceId: c.deviceId,
                                           clientNonce: c.clientNonce, serverNonce: s.serverNonce)
        guard Crypto.constantTimeEqual(expected, c.proof) else {
            Log.warn("Invalid auth proof for \(Log.short(c.deviceId))")
            reject(s, type: MsgType.authFailed, reason: Reason.invalidProof); return
        }
        if let current = active {
            // Same phone reconnecting (e.g. after a Wi-Fi change): replace the stale session quietly.
            guard current.deviceId == c.deviceId else { reject(s, type: MsgType.authFailed, reason: Reason.busy); return }
            close(current, notify: false)
        }
        device.lastSeen = Date()
        devices.upsert(device)
        s.timeout?.cancel()
        let proof = Handshake.serverProof(secret: secret, clientNonce: c.clientNonce, serverNonce: s.serverNonce)
        s.sessionKey = Handshake.sessionKey(secret: secret, clientNonce: c.clientNonce, serverNonce: s.serverNonce)
        send(s, ["type": MsgType.authOK, "serverProof": proof.base64URLEncodedString(),
                 "accessibility": input.isTrusted])
        promote(s, device: device)
        Log.info("Authenticated \(Log.short(c.deviceId))")
    }

    private func promote(_ s: Session, device: PairedDevice) {
        s.stage = .authenticated
        s.deviceId = device.id
        s.lastActivity = Date()
        s.lastSeq = 0
        s.lastTrusted = input.isTrusted
        active = s
        onMain { $0.server(self, didAuthenticate: device) }
    }

    // MARK: Input (Part 2)

    /// Order of checks: field types -> MAC -> sequence -> rate limit -> parse. Only then does anything reach the engine.
    private func handleInput(_ s: Session, _ obj: [String: Any]) {
        guard let key = s.sessionKey,
              let seq = InputParser.int(obj["seq"]), seq > 0,
              let t = InputParser.int(obj["t"]), t >= 0,
              let body = obj["body"] as? String, body.utf8.count <= InputLimits.maxBodyBytes,
              let macText = obj["mac"] as? String, let mac = Data(base64URLEncoded: macText) else {
            invalidInput(s, Reason.invalidCommand); return
        }
        guard Crypto.constantTimeEqual(Handshake.inputMac(key: key, seq: seq, body: body), mac) else {
            invalidInput(s, Reason.badMac); return
        }
        guard seq > s.lastSeq else { invalidInput(s, Reason.badSeq); return }   // replay or reorder
        s.lastSeq = seq

        guard s.limiter.allow() else {
            s.dropStreak += 1
            if s.dropStreak > InputLimits.maxDropStreak { invalidInput(s, Reason.rateLimited) }
            return
        }
        s.dropStreak = 0

        do {
            input.apply(try InputParser.parse(body))
        } catch {
            Log.warn("Invalid input from \(Log.short(s.deviceId ?? "?")): \(error)")
            invalidInput(s, Reason.invalidCommand)
        }
    }

    /// Any invalid command releases every button and key and ends the session.
    private func invalidInput(_ s: Session, _ reason: String) {
        Log.warn("Closing session: \(reason)")
        input.releaseAll()
        reject(s, type: MsgType.error, reason: reason)
    }

    /// Tells the phone when the Accessibility permission changes while it is connected.
    private func pushStatusIfChanged() {
        guard let a = active else { return }
        let trusted = input.isTrusted
        guard a.lastTrusted != trusted else { return }
        a.lastTrusted = trusted
        if !trusted { input.releaseAll() }
        send(a, ["type": MsgType.status, "accessibility": trusted])
    }

    // MARK: Helpers

    private func setState(_ state: State) { onMain { $0.server(self, didChangeState: state) } }

    private func onMain(_ work: @escaping (MacTouchServerDelegate) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let delegate = self.delegate else { return }
            work(delegate)
        }
    }
}
