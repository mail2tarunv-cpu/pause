import SwiftUI

enum PAUSEPalette {
    static let background = Color(red: 0.966, green: 0.960, blue: 0.945)
    static let surface = Color(red: 0.994, green: 0.990, blue: 0.980)
    static let ink = Color(red: 0.152, green: 0.164, blue: 0.154)
    static let secondary = Color(red: 0.48, green: 0.50, blue: 0.47)
    static let line = Color(red: 0.87, green: 0.87, blue: 0.84)
    static let orange = Color(red: 0.91, green: 0.57, blue: 0.32)
    static let sage = Color(red: 0.79, green: 0.85, blue: 0.77)
    static let board = Color(red: 0.095, green: 0.105, blue: 0.102)
}

struct PAUSEPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 22)
            .padding(.top, 26)
        }
        .background(PAUSEPalette.background.ignoresSafeArea())
    }
}

struct PAUSEHeader: View {
    let eyebrow: String
    let headline: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("PAUSE").tracking(4.4)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Spacer()
                Text(eyebrow.uppercased())
                    .tracking(1.3)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PAUSEPalette.secondary)
            }
            .padding(.bottom, 16)

            Text(headline)
                .font(.system(size: 39, weight: .medium, design: .rounded))
                .tracking(-1.8)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(PAUSEPalette.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(PAUSEPalette.ink)
    }
}

struct PAUSECard<Content: View>: View {
    let content: Content
    var color: Color = PAUSEPalette.surface

    init(color: Color = PAUSEPalette.surface, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 21))
            .overlay(
                RoundedRectangle(cornerRadius: 21)
                    .strokeBorder(PAUSEPalette.ink.opacity(0.045), lineWidth: 1)
            )
    }
}

struct PAUSEKicker: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(PAUSEPalette.secondary)
    }
}

struct PAUSEButton: ButtonStyle {
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .foregroundStyle(filled ? PAUSEPalette.surface : PAUSEPalette.ink)
            .background(
                filled ? PAUSEPalette.ink : PAUSEPalette.background,
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(PAUSEPalette.line, lineWidth: filled ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct PAUSEStatusPill: View {
    let text: String
    let positive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(positive ? Color(red: 0.32, green: 0.55, blue: 0.38) : PAUSEPalette.orange)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(PAUSEPalette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(PAUSEPalette.background, in: Capsule())
    }
}

struct PAUSEStatusNotice: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(PAUSEPalette.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
        .lineSpacing(3)
        .foregroundStyle(PAUSEPalette.secondary)
        .padding(.horizontal, 3)
    }
}

struct PAUSEField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13))
            .padding(13)
            .background(PAUSEPalette.background, in: RoundedRectangle(cornerRadius: 11))
            .autocorrectionDisabled()
    }
}

extension View {
    func pauseField() -> some View { modifier(PAUSEField()) }
}
