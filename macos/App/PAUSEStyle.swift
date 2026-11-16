import SwiftUI
import AppKit
import CoreText

/// Font assets bundled by XcodeGen and registered once for the process.
/// No requirement to install a font globally on the user's Mac.
enum PAUSEMacFonts {
    static func register() {
        for family in [
            "SpaceGrotesk-Regular", "SpaceGrotesk-Medium", "SpaceGrotesk-Bold",
            "DMMono-Regular", "DMMono-Medium"
        ] {
            guard let url = Bundle.main.url(forResource: family, withExtension: "ttf") else {
                NSLog("PAUSE font missing: %@", family)
                continue
            }
            CTFontManagerRegisterFontsForURL(url, .process, nil)
        }
    }
}

enum PAUSEMacPalette {
    static let paper = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.085, alpha: 1)
            : NSColor(calibratedRed: 0.969, green: 0.969, blue: 0.957, alpha: 1)
    })
    static let surface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedWhite: 0.16, alpha: 1)
            : NSColor.white
    })
    static let ink = Color.primary
    static let secondary = Color.secondary
    static let tint = Color(red: 0.06, green: 0.48, blue: 0.42)
    static let orange = Color(red: 1.0, green: 0.36, blue: 0.06)
    static let yellow = Color(red: 1.0, green: 0.88, blue: 0.03)
    static let pink = Color(red: 0.96, green: 0.31, blue: 0.90)
    static let cyan = Color(red: 0.06, green: 0.83, blue: 0.88)
    static let lime = Color(red: 0.63, green: 0.96, blue: 0.36)
    static let violet = Color(red: 0.34, green: 0.29, blue: 0.98)
}

enum PAUSEMacType {
    private static func size(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 38
        case .title: return 31
        case .title2: return 25
        case .title3: return 21
        case .headline: return 17
        case .subheadline: return 14
        case .callout: return 14
        case .footnote: return 12
        case .caption: return 11
        case .caption2: return 10
        default: return 15
        }
    }
    static func heading(_ style: Font.TextStyle = .title2) -> Font {
        .custom("SpaceGrotesk-Bold", size: size(style), relativeTo: style)
    }
    static func body(_ style: Font.TextStyle = .body, strong: Bool = false) -> Font {
        .custom(strong ? "DMMono-Medium" : "DMMono-Regular",
                size: size(style), relativeTo: style)
    }
}

struct PAUSEMacShapeStamp: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 24, topTrailingRadius: 0
            ).fill(PAUSEMacPalette.orange).frame(width: 24, height: 24)
            Circle().fill(PAUSEMacPalette.yellow).frame(width: 17, height: 17)
            PAUSEMacTriangle().fill(PAUSEMacPalette.pink).frame(width: 20, height: 24)
        }
        .accessibilityHidden(true)
    }
}

private struct PAUSEMacTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
