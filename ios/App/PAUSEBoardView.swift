import SwiftUI

struct PAUSEBoardView: View {
    @ObservedObject var model: PAUSEModel

    var body: some View {
        PAUSEPage {
            PAUSEHeader(
                eyebrow: "Your ambient display",
                headline: "A thought,\nout in the open.",
                description: "Compose a message on iPhone. Send it to your digital split-flap board whenever a paired board is available."
            )

            PAUSECard(color: PAUSEPalette.board) {
                HStack {
                    Text("PAUSE BOARD / PREVIEW")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                    Spacer()
                    Image(systemName: "circle.grid.3x3.fill")
                }
                .foregroundStyle(Color.white.opacity(0.48))
                PAUSEFlapPreview(message: model.boardDraft)
                    .padding(.vertical, 12)
                Text("6 rows × 22 characters")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }

            PAUSECard {
                PAUSEKicker(text: "01 / Compose")
                Text("Your message")
                    .font(.system(size: 16, weight: .semibold))
                TextEditor(text: $model.boardDraft)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(PAUSEPalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(height: 125)
                    .background(PAUSEPalette.background, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: model.boardDraft) { _, next in
                        if next.count > 280 {
                            model.boardDraft = String(next.prefix(280))
                        }
                    }
                HStack {
                    Text("Letters, numbers and basic punctuation")
                        .font(.system(size: 10))
                        .foregroundStyle(PAUSEPalette.secondary)
                    Spacer()
                    Text("\(model.boardDraft.count) / 280")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PAUSEPalette.secondary)
                }
                Button {
                    Task { await model.sendCustomMessage() }
                } label: {
                    Label("Send to board", systemImage: "arrow.up.right")
                }
                .buttonStyle(PAUSEButton())
                .disabled(model.isWorking || model.boardDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear board message") {
                    Task { await model.clearBoard() }
                }
                .buttonStyle(PAUSEButton(filled: false))
                .disabled(model.isWorking)
            }

            PAUSECard {
                PAUSEKicker(text: "02 / Test your nudge")
                HStack(spacing: 12) {
                    Image(systemName: model.category.icon)
                        .font(.system(size: 20))
                        .frame(width: 39, height: 39)
                        .background(PAUSEPalette.background, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.category.title + " check-in")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Simulated event — not a real Screen Time reading")
                            .font(.system(size: 11))
                            .foregroundStyle(PAUSEPalette.secondary)
                    }
                }
                Button("Send test nudge") {
                    Task { await model.sendExampleNudge() }
                }
                .buttonStyle(PAUSEButton(filled: false))
                .disabled(model.isWorking)
            }

            PAUSECard {
                HStack {
                    PAUSEKicker(text: "03 / Pair a board")
                    Spacer()
                    PAUSEStatusPill(text: model.boardConnected ? "Paired" : "Optional", positive: model.boardConnected)
                }
                Text("Works without a Mac")
                    .font(.system(size: 16, weight: .semibold))
                Text("The Screen Time dashboard and nudges work entirely on your iPhone. Connect a board only when you want messages to appear on another screen.")
                    .font(.system(size: 12))
                    .foregroundStyle(PAUSEPalette.secondary)
                    .lineSpacing(3)

                Text("Mac board address")
                    .font(.system(size: 11, weight: .semibold))
                TextField("http://192.168.1.10:8765", text: $model.boardAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .pauseField()

                Text("Private pairing code")
                    .font(.system(size: 11, weight: .semibold))
                SecureField("From your Mac's PAUSE relay", text: $model.boardKey)
                    .textInputAutocapitalization(.never)
                    .pauseField()

                Button("Pair with board") {
                    Task { await model.pairBoard() }
                }
                .buttonStyle(PAUSEButton(filled: false))
                .disabled(model.isWorking)
                Text("The existing Python relay is only a temporary bridge. We will replace it with the native Mac app later. Use trusted private Wi-Fi only.")
                    .font(.system(size: 10))
                    .foregroundStyle(PAUSEPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PAUSEStatusNotice(text: model.status)
        }
    }
}

struct PAUSEFlapPreview: View {
    let message: String

    private var characters: [String] {
        var rows: [String] = []
        for line in message.uppercased().components(separatedBy: "\n") {
            let symbols = Array(line)
            if symbols.isEmpty {
                rows.append("")
                continue
            }
            for offset in stride(from: 0, to: symbols.count, by: 22) {
                let upper = min(symbols.count, offset + 22)
                rows.append(String(symbols[offset..<upper]))
            }
        }
        rows = Array(rows.prefix(6))
        let blankRows = max(0, 6 - rows.count)
        let start = blankRows / 2
        var tiles = Array(repeating: " ", count: 6 * 22)
        for (rowIndex, row) in rows.enumerated() {
            let symbols = Array(row)
            let left = (22 - symbols.count) / 2
            for (index, character) in symbols.enumerated() {
                tiles[(start + rowIndex) * 22 + left + index] = String(character)
            }
        }
        return tiles
    }

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 1.7
            let cellWidth = (proxy.size.width - 21 * gap) / 22
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: gap), count: 22),
                spacing: 2.1
            ) {
                ForEach(characters.indices, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(red: 0.16, green: 0.17, blue: 0.17))
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .frame(height: 1)
                        Text(characters[index])
                            .font(.system(size: max(6, cellWidth * 0.62), weight: .medium, design: .monospaced))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundStyle(Color(red: 0.93, green: 0.93, blue: 0.89))
                    }
                    .frame(height: max(13, cellWidth * 1.35))
                }
            }
        }
        .frame(height: 136)
        .accessibilityLabel("Preview of the message on a six by twenty-two split-flap board")
    }
}
