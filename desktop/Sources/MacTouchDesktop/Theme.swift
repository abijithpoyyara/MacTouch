import SwiftUI
import AppKit

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// MacTouch palette. Mirrors mobile/lib/core/theme/app_theme.dart.
enum MT {
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }

    static let background  = dynamic(light: 0xEEF0F5, dark: 0x14171D)
    static let surface     = dynamic(light: 0xFFFFFF, dark: 0x1D2129)
    static let surfaceHigh = dynamic(light: 0xE4E7EE, dark: 0x272C36)
    static let outline     = dynamic(light: 0xD3D8E2, dark: 0x343A46)
    static let text        = dynamic(light: 0x161922, dark: 0xECEFF4)
    static let textDim     = dynamic(light: 0x5C6577, dark: 0x98A1B3)
    static let accent      = dynamic(light: 0x5B3FF0, dark: 0x8D79FF)
    static let onAccent    = dynamic(light: 0xFFFFFF, dark: 0x12101F)
    static let success     = dynamic(light: 0x14946B, dark: 0x38C99B)
    static let danger      = dynamic(light: 0xD8374A, dark: 0xFF6B7A)
    static let warning     = dynamic(light: 0xA86400, dark: 0xF2B24B)

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

struct MTButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .foregroundStyle(foreground)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(kind == .primary ? Color.clear : MT.outline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind { case .primary: return MT.onAccent; case .secondary: return MT.text; case .destructive: return MT.danger }
    }
    private var fill: Color {
        switch kind { case .primary: return MT.accent; case .secondary, .destructive: return MT.surfaceHigh }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(MT.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MT.outline, lineWidth: 1))
    }
}
