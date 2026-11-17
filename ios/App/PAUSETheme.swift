import SwiftUI
import UIKit

/// Native PAUSE chrome follows the system appearance and Dynamic Type.
/// The colorful hardware identity belongs in the split-flap preview.
enum PAUSEPalette {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color.primary
    static let secondary = Color.secondary
    static let line = Color(uiColor: .separator)
    static let tint = Color.accentColor
    static let board = Color(red: 0.09, green: 0.09, blue: 0.10)

    // Used by the hardware tiles and a small number of category indicators.
    static let orange = Color(red: 1.0, green: 0.36, blue: 0.06)
    static let yellow = Color(red: 1.0, green: 0.88, blue: 0.03)
    static let pink = Color(red: 0.96, green: 0.31, blue: 0.90)
    static let cyan = Color(red: 0.06, green: 0.83, blue: 0.88)
    static let violet = Color(red: 0.34, green: 0.29, blue: 0.98)
    static let lime = Color(red: 0.63, green: 0.96, blue: 0.36)
}

/// Platform typography, not a custom font masquerading as a native control.
/// Only the split-flap preview uses DM Mono.
enum PAUSEType {
    static func heading(_ style: Font.TextStyle = .title2, bold: Bool = true) -> Font {
        .system(style, design: .default, weight: bold ? .bold : .semibold)
    }

    static func body(_ style: Font.TextStyle = .body, strong: Bool = false) -> Font {
        .system(style, design: .default, weight: strong ? .semibold : .regular)
    }
}

struct PAUSESectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .textCase(nil)
    }
}

/// A short introduction, aligned with iOS grouped-list insets.
struct PAUSEIntro: View {
    let title: String
    let subtitle: String
    var symbol: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let symbol {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6)
    }
}

struct PAUSEInfoRow: View {
    let symbol: String
    let title: String
    let explanation: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)
        }
    }
}

struct PAUSEStatusNotice: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}

struct PAUSESectionAction: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
    }
}
extension View {
    func pausePrimaryAction() -> some View { modifier(PAUSESectionAction()) }
}
