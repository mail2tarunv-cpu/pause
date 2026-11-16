import SwiftUI

/// System-first PAUSE design language.
/// Keep custom drawing for the split-flap object, not for standard controls.
enum PAUSEPalette {
    static let tint = Color(red: 0.16, green: 0.42, blue: 0.44)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color.primary
    static let secondary = Color.secondary
    static let line = Color(uiColor: .separator)
    static let sage = Color(uiColor: .tertiarySystemFill)
    static let board = Color(red: 0.09, green: 0.10, blue: 0.10)
}

struct PAUSEIntro: View {
    let title: String
    let subtitle: String
    var symbol: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct PAUSEInfoRow: View {
    let symbol: String
    let title: String
    let explanation: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
    }
}

struct PAUSESectionAction: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func pausePrimaryAction() -> some View { modifier(PAUSESectionAction()) }
}
