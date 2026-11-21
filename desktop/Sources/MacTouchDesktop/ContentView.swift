import SwiftUI
import MacTouchCore

enum Pane: String, CaseIterable, Identifiable {
    case overview, devices, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.33percent"
        case .devices: return "iphone.gen3"
        case .settings: return "gearshape"
        }
    }
}

/// Which pane is showing. A small object instead of @State, because @State is a macro in the newest macOS SDK and the
/// Command Line Tools cannot expand it.
final class NavState: ObservableObject {
    @Published var pane: Pane = .overview
}

final class DevicesUI: ObservableObject {
    @Published var deviceToForget: PairedDevice?
}

/// The main window: a quiet sidebar and three panes.
struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var nav = NavState()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(nav: nav)
                .frame(width: 200)
            Divider().overlay(MT.outline)
            ScrollView {
                Group {
                    switch nav.pane {
                    case .overview: OverviewPane()
                    case .devices: DevicesPane()
                    case .settings: SettingsPane()
                    }
                }
                .padding(28)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .background(MT.background)
        .frame(minWidth: 820, minHeight: 560)
    }
}

private struct Sidebar: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var nav: NavState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MT.accent)
                    Image(systemName: "hand.point.up.left.fill").font(.system(size: 15)).foregroundStyle(MT.onAccent)
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
                Text("MacTouch").font(MT.title(18)).foregroundStyle(MT.text)
            }
            .padding(.bottom, 14)

            ForEach(Pane.allCases) { p in
                Button { nav.pane = p } label: {
                    HStack(spacing: 10) {
                        Image(systemName: p.symbol).frame(width: 18)
                        Text(p.title)
                        Spacer()
                        if p == .devices, model.connectedDevice != nil {
                            Circle().fill(MT.success).frame(width: 8, height: 8).accessibilityLabel("A phone is connected")
                        }
                        if p == .overview, !model.issues.isEmpty {
                            Circle().fill(MT.warning).frame(width: 8, height: 8).accessibilityLabel("Needs attention")
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(nav.pane == p ? MT.text : MT.textDim)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(nav.pane == p ? MT.surfaceHigh : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(nav.pane == p ? .isSelected : [])
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(model.isRunning ? MT.success : MT.textDim).frame(width: 8, height: 8)
                Text(model.isRunning ? "Server on" : "Server off").font(.system(size: 12)).foregroundStyle(MT.textDim)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .background(MT.surface.opacity(0.5))
    }
}

// MARK: Overview

private struct OverviewPane: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            hero
            ForEach(Array(model.issues.enumerated()), id: \.offset) { _, issue in IssueCard(issue: issue) }
            serverCard
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.headline).font(MT.title(28)).foregroundStyle(MT.text)
                Text(model.subheadline).font(.system(size: 14)).foregroundStyle(MT.textDim)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 10) {
                Button {
                    openWindow(id: "pair")
                    NSApp.activate(ignoringOtherApps: true)
                } label: { Label("Pair a phone", systemImage: "qrcode") }
                    .buttonStyle(MTButtonStyle(kind: .primary))
                    .disabled(!model.isRunning)
                if model.connectedDevice != nil {
                    Button("Disconnect") { model.disconnectDevice() }.buttonStyle(MTButtonStyle(kind: .secondary))
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [MT.accent.opacity(0.18), MT.accent.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MT.outline, lineWidth: 1))
    }

    private var serverCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Server").font(.system(size: 14, weight: .semibold)).foregroundStyle(MT.text)
                    Text(serverDetail).font(.system(size: 12)).foregroundStyle(MT.textDim)
                }
                Spacer()
                if model.isRunning || model.status == .starting {
                    Button("Restart") { model.restartServer() }.buttonStyle(MTButtonStyle(kind: .secondary))
                    Button("Stop") { model.stopServer() }.buttonStyle(MTButtonStyle(kind: .secondary))
                } else {
                    Button("Start") { model.startServer() }.buttonStyle(MTButtonStyle(kind: .primary))
                }
            }
        }
    }

    private var serverDetail: String {
        switch model.status {
        case .running: return model.localIP.map { "Running on \($0), port \(model.port)" } ?? "Running, but there is no local network address"
        case .starting: return "Starting\u{2026}"
        case .stopped: return "Stopped. Phones cannot connect."
        case .failed: return "Not running"
        }
    }
}

private struct IssueCard: View {
    @EnvironmentObject var model: AppModel
    let issue: AppModel.Issue

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(tint).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(MT.text)
                    Text(message).font(.system(size: 12)).foregroundStyle(MT.textDim).fixedSize(horizontal: false, vertical: true)
                    actions
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var symbol: String {
        switch issue {
        case .serverFailed: return "xmark.octagon.fill"
        case .noNetwork: return "wifi.slash"
        case .accessibilityMissing: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        if case .serverFailed = issue { return MT.danger }
        return MT.warning
    }

    private var title: String {
        switch issue {
        case .serverFailed: return "MacTouch could not start its server"
        case .noNetwork: return "No local network"
        case .accessibilityMissing: return "Accessibility permission needed"
        }
    }

    private var message: String {
        switch issue {
        case .serverFailed(let reason):
            return "\(reason) If another copy of MacTouch is open, quit it, then try again. If macOS asked about incoming connections, choose Allow."
        case .noNetwork:
            return "Connect this Mac to Wi-Fi or Ethernet. Your phone has to be on the same network."
        case .accessibilityMissing:
            return "macOS only lets an app control the pointer after you allow it in System Settings > Privacy & Security > Accessibility. If you started MacTouch with `swift run`, allow Terminal instead. This status refreshes by itself."
        }
    }

    @ViewBuilder private var actions: some View {
        switch issue {
        case .serverFailed:
            Button("Try again") { model.startServer() }.buttonStyle(MTButtonStyle(kind: .primary))
        case .noNetwork:
            EmptyView()
        case .accessibilityMissing:
            HStack {
                Button("Open System Settings") { model.requestAccessibility() }.buttonStyle(MTButtonStyle(kind: .primary))
                Button("Check again") { model.recheckAccessibility() }.buttonStyle(MTButtonStyle(kind: .secondary))
            }
        }
    }
}

// MARK: Devices and history

private struct DevicesPane: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var ui = DevicesUI()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Devices").font(MT.title(26)).foregroundStyle(MT.text)

            section("Paired phones") {
                if model.pairedDevices.isEmpty {
                    Card { Text("No phones are paired yet. Use \u{201C}Pair a phone\u{201D} on the Overview.").font(.system(size: 13)).foregroundStyle(MT.textDim) }
                } else {
                    ForEach(model.pairedDevices) { device in deviceRow(device) }
                }
            }

            section("Connection history", trailing: AnyView(
                Button("Clear") { model.clearHistory() }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(MT.accent)
                    .disabled(model.history.isEmpty)
            )) {
                if model.history.isEmpty {
                    Card { Text("Nothing yet. Pairings, connections and server events are listed here.").font(.system(size: 13)).foregroundStyle(MT.textDim) }
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.history.prefix(30)) { entry in historyRow(entry) }
                        }
                    }
                }
            }
        }
        .confirmationDialog("Forget this phone?", isPresented: Binding(get: { ui.deviceToForget != nil }, set: { if !$0 { ui.deviceToForget = nil } }),
                            titleVisibility: .visible, presenting: ui.deviceToForget) { device in
            Button("Forget \(device.name)", role: .destructive) { model.forget(device) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It will have to scan a new code to connect again. Its saved key is deleted from this Mac.")
        }
    }

    private func section<Content: View>(_ title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.7).foregroundStyle(MT.textDim)
                Spacer()
                trailing
            }
            content()
        }
    }

    private func deviceRow(_ device: PairedDevice) -> some View {
        let connected = model.connectedDevice?.id == device.id
        return Card {
            HStack(spacing: 12) {
                Image(systemName: "iphone.gen3").font(.system(size: 20)).foregroundStyle(MT.accent).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(MT.text)
                    Text(connected ? "Connected now" : "Last seen \(device.lastSeen.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "never")  \u{00B7}  paired \(device.pairedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12)).foregroundStyle(connected ? MT.success : MT.textDim)
                }
                Spacer()
                if connected { Button("Disconnect") { model.disconnectDevice() }.buttonStyle(MTButtonStyle(kind: .secondary)) }
                Button("Forget") { ui.deviceToForget = device }.buttonStyle(MTButtonStyle(kind: .destructive))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func historyRow(_ e: HistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol(e.kind)).foregroundStyle(tint(e.kind)).frame(width: 18).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text([e.kind.title, e.device].compactMap { $0 }.joined(separator: " \u{00B7} "))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(MT.text)
                if let detail = e.detail { Text(detail).font(.system(size: 12)).foregroundStyle(MT.textDim) }
            }
            Spacer()
            Text(e.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 11)).foregroundStyle(MT.textDim)
        }
        .accessibilityElement(children: .combine)
    }

    private func symbol(_ k: HistoryKind) -> String {
        switch k {
        case .serverStarted: return "play.circle"
        case .serverStopped: return "stop.circle"
        case .serverFailed: return "exclamationmark.octagon"
        case .paired: return "link"
        case .declined: return "hand.raised"
        case .connected: return "checkmark.circle"
        case .disconnected: return "link.badge.plus"
        }
    }

    private func tint(_ k: HistoryKind) -> Color {
        switch k {
        case .serverFailed: return MT.danger
        case .declined: return MT.warning
        case .connected, .paired, .serverStarted: return MT.success
        default: return MT.textDim
        }
    }
}

// MARK: Settings

private struct SettingsPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings").font(MT.title(26)).foregroundStyle(MT.text)

            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name shown on your phone").font(.system(size: 14, weight: .semibold)).foregroundStyle(MT.text)
                    TextField("Mac name", text: $model.deviceName).textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                    Text("Phones that scan the next code see this name.").font(.system(size: 12)).foregroundStyle(MT.textDim)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    row("Start the server when MacTouch opens", isOn: $model.autoStartServer)
                    Divider().overlay(MT.outline)
                    row("Show menu bar icon", isOn: $model.showMenuBarIcon, disabled: !model.showDockIcon)
                    row("Show Dock icon", isOn: $model.showDockIcon, disabled: !model.showMenuBarIcon)
                    Text("At least one of the menu bar icon and the Dock icon stays on, so you can always open MacTouch.")
                        .font(.system(size: 12)).foregroundStyle(MT.textDim)
                    Divider().overlay(MT.outline)
                    row("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    if let message = model.launchAtLoginMessage {
                        Text(message).font(.system(size: 12)).foregroundStyle(MT.warning).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Network port").font(.system(size: 14, weight: .semibold)).foregroundStyle(MT.text)
                        Text("\(model.port)  \u{00B7}  fixed, so phones can find this Mac again after pairing").font(.system(size: 12)).foregroundStyle(MT.textDim)
                    }
                    Spacer()
                    Button("Restart server") { model.restartServer() }.buttonStyle(MTButtonStyle(kind: .secondary)).disabled(!model.isRunning)
                }
            }

            Text("MacTouch 0.4.0").font(.system(size: 12)).foregroundStyle(MT.textDim)
        }
    }

    private func row(_ title: String, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        Toggle(isOn: isOn) {
            Text(title).font(.system(size: 13)).foregroundStyle(MT.text)
        }
        .toggleStyle(.switch)
        .disabled(disabled)
    }
}
