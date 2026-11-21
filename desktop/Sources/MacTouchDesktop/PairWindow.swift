import SwiftUI
import MacTouchCore

/// A small window that only shows the pairing QR code and what to do with it.
struct PairWindow: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Pair a phone").font(MT.title(24)).foregroundStyle(MT.text)
                Text("Open MacTouch on your phone and scan this code.")
                    .font(.system(size: 13)).foregroundStyle(MT.textDim)
            }
            .accessibilityElement(children: .combine)

            slab

            footer
        }
        .padding(28)
        .frame(width: 400)
        .background(MT.background)
    }

    @ViewBuilder private var slab: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous).fill(MT.surface)
            RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(MT.outline, lineWidth: 1)
            content.padding(24)
        }
        .frame(height: 340)
    }

    @ViewBuilder private var content: some View {
        if model.pending != nil {
            StateMessage(symbol: "hourglass", tint: MT.accent, title: "Waiting for your approval",
                         detail: "Confirm the pairing request on this Mac.")
        } else if case .failed(let message) = model.status {
            StateMessage(symbol: "xmark.octagon", tint: MT.danger, title: "Server could not start", detail: message) {
                Button("Try again") { model.startServer() }.buttonStyle(MTButtonStyle(kind: .primary))
            }
        } else if case .stopped = model.status {
            StateMessage(symbol: "pause.circle", tint: MT.textDim, title: "Server is stopped",
                         detail: "Start the server to show a pairing code.") {
                Button("Start server") { model.startServer() }.buttonStyle(MTButtonStyle(kind: .primary))
            }
        } else if model.status == .starting {
            StateMessage(symbol: "bolt.horizontal", tint: MT.warning, title: "Starting\u{2026}", detail: nil)
        } else if !model.networkAvailable || model.localIP == nil {
            StateMessage(symbol: "wifi.slash", tint: MT.warning, title: "No local network",
                         detail: "Connect this Mac to the same Wi-Fi as your phone.")
        } else if let image = model.qrImage {
            Image(nsImage: image)
                .interpolation(.none).resizable()
                .frame(width: 252, height: 252)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))   // quiet zone
                .accessibilityLabel("Pairing QR code. Scan it with MacTouch on your phone.")
        } else {
            StateMessage(symbol: "qrcode", tint: MT.accent, title: "Preparing code\u{2026}", detail: nil)
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 4) {
            if let expires = model.qrExpiresAt, model.qrImage != nil, model.pending == nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(expires.timeIntervalSince(context.date)))
                    Text("New code in \(left / 60):\(String(format: "%02d", left % 60))")
                        .font(.system(size: 12).monospacedDigit()).foregroundStyle(MT.textDim)
                }
            }
            Text(model.localIP.map { "Your Mac: \($0):\(model.port). Phone and Mac must be on the same network." }
                 ?? "Phone and Mac must be on the same network.")
                .font(.system(size: 12)).foregroundStyle(MT.textDim).multilineTextAlignment(.center)
        }
    }
}

/// Icon, title, optional detail and optional action. Used for every empty or error state.
struct StateMessage<Action: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String?
    @ViewBuilder var action: Action

    init(symbol: String, tint: Color, title: String, detail: String?, @ViewBuilder action: () -> Action) {
        self.symbol = symbol; self.tint = tint; self.title = title; self.detail = detail; self.action = action()
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 38)).foregroundStyle(tint).accessibilityHidden(true)
            Text(title).font(MT.title(18)).foregroundStyle(MT.text).multilineTextAlignment(.center)
            if let detail {
                Text(detail).font(.system(size: 13)).foregroundStyle(MT.textDim).multilineTextAlignment(.center)
            }
            action.padding(.top, 4)
        }
        .frame(maxWidth: 320)
        .accessibilityElement(children: .contain)
    }
}

extension StateMessage where Action == EmptyView {
    init(symbol: String, tint: Color, title: String, detail: String?) {
        self.init(symbol: symbol, tint: tint, title: title, detail: detail) { EmptyView() }
    }
}
