import SwiftUI
import UIKit

/// PAUSE's editorial palette. The reference artwork's electric colors are
/// accents; text and form controls retain reliable system-level contrast.
enum PAUSEPalette {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        func component(_ value: UInt32, shift: UInt32) -> CGFloat {
            CGFloat((value >> shift) & 0xff) / 255
        }
        let provider = UIColor { traits in
            let color = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: component(color, shift: 16),
                           green: component(color, shift: 8),
                           blue: component(color, shift: 0), alpha: 1)
        }
        return Color(uiColor: provider)
    }

    static let background = adaptive(0xF7F7F5, 0x131314)
    static let surface = adaptive(0xFFFFFF, 0x242426)
    static let ink = adaptive(0x101012, 0xFAF9F7)
    static let secondary = adaptive(0x55575A, 0xB4B3B7)
    static let line = adaptive(0xDCDDD9, 0x3A3A3E)
    static let tint = adaptive(0x08796D, 0x66DCCC)
    static let orange = Color(red: 1.0, green: 0.36, blue: 0.06)
    static let yellow = Color(red: 1.0, green: 0.88, blue: 0.03)
    static let pink = Color(red: 0.96, green: 0.31, blue: 0.90)
    static let cyan = Color(red: 0.06, green: 0.83, blue: 0.88)
    static let violet = Color(red: 0.34, green: 0.29, blue: 0.98)
    static let lime = Color(red: 0.63, green: 0.96, blue: 0.36)
    static let board = Color(red: 0.09, green: 0.09, blue: 0.10)
}

/// Dynamic Type-respecting custom type families.
/// Headings: Space Grotesk / Body, actions and metadata: DM Mono.
/// AppIcon and SF Symbols are not fonts and retain their platform behavior.
enum PAUSEType {
    private static func points(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 36
        case .title: return 31
        case .title2: return 24
        case .title3: return 21
        case .headline: return 17
        case .subheadline: return 14
        case .footnote: return 12
        case .caption: return 11
        case .caption2: return 10
        default: return 15
        }
    }

    static func heading(_ style: Font.TextStyle = .title2,
                        bold: Bool = true) -> Font {
        Font.custom(bold ? "SpaceGrotesk-Bold" : "SpaceGrotesk-Medium",
                    size: points(style), relativeTo: style)
    }

    static func body(_ style: Font.TextStyle = .body,
                     strong: Bool = false) -> Font {
        Font.custom(strong ? "DMMono-Medium" : "DMMono-Regular",
                    size: points(style), relativeTo: style)
    }
}

/// Small original geometric motifs inspired by the supplied typography poster.
/// Decorative only. Never replace SF Symbols on actionable controls.
struct PAUSEShapeStamp: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            PAUSEQuarterShape()
                .fill(PAUSEPalette.orange)
                .frame(width: 22, height: 22)
            Circle().fill(PAUSEPalette.yellow)
                .frame(width: 15, height: 15)
            TriangleShape().fill(PAUSEPalette.pink)
                .frame(width: 18, height: 20)
        }
        .accessibilityHidden(true)
    }
}

private struct PAUSEQuarterShape: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                           control: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

private struct TriangleShape: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

struct PAUSEIntro: View {
    let title: String
    let subtitle: String
    var symbol: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                PAUSEShapeStamp()
                    .padding(.bottom, 2)
                Text(title)
                    .font(PAUSEType.heading(.title2))
                    .foregroundStyle(PAUSEPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(PAUSEType.body(.subheadline))
                    .foregroundStyle(PAUSEPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let symbol {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(PAUSEPalette.tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

struct PAUSEInfoRow: View {
    let symbol: String
    let title: String
    let explanation: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(PAUSEType.body(.body, strong: true))
                Text(explanation)
                    .font(PAUSEType.body(.subheadline))
                    .foregroundStyle(PAUSEPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(PAUSEPalette.tint)
                .frame(width: 24)
        }
    }
}

struct PAUSEStatusNotice: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(PAUSEType.body(.footnote))
            .foregroundStyle(PAUSEPalette.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}

struct PAUSESectionAction: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(PAUSEType.body(.body, strong: true))
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func pausePrimaryAction() -> some View { modifier(PAUSESectionAction()) }
}
