import SwiftUI

struct PAUSEBoardView: View {
    @ObservedObject var model: PAUSEModel
    @ObservedObject private var cloud = PAUSECloud.shared
    @FocusState private var composing: Bool
    @State private var localExpanded = false

    private var boardLayout: PAUSEBoardLayout {
        PAUSEBoardLayout(message: model.boardDraft)
    }
    private var canSend: Bool {
        !model.boardDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !boardLayout.overflow && !model.isWorking
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    PAUSEFlapPreview(message: model.boardDraft)
                    HStack {
                        Label("6 rows × 22 columns", systemImage: "rectangle.grid.1x2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(boardLayout.overflow ? "Too many rows" : "Live preview")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(boardLayout.overflow ? Color.red : Color.secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Preview")
            } footer: {
                Text("The preview shows the layout of your physical display.")
            }

            Section {
                TextEditor(text: $model.boardDraft)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .frame(height: 108)
                    .focused($composing)
                    .accessibilityLabel("Message for the board")
                    .onChange(of: model.boardDraft) { _, text in
                        if text.count > 280 {
                            model.boardDraft = String(text.prefix(280))
                        }
                    }
                HStack(spacing: 12) {
                    Text(boardLayout.overflow ? "Shorten your message to six rows." :
                         "Text is centered automatically.")
                        .foregroundStyle(boardLayout.overflow ? Color.red : Color.secondary)
                    Spacer()
                    Text("\(model.boardDraft.count)/280")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            } header: {
                Text("Message")
            }

            Section {
                LabeledContent("Cloud account", value: cloud.signedIn ? "Signed in" : "Not connected")

                Button {
                    composing = false
                    Task { await cloud.sendBoard(model.boardDraft) }
                } label: {
                    Label("Send to Display", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!cloud.signedIn || !canSend)

                if cloud.signedIn {
                    Button("Clear Display", role: .destructive) {
                        Task { await cloud.sendBoard(nil) }
                    }
                }
            } header: {
                Text("Delivery")
            } footer: {
                Text(cloud.signedIn ? cloud.status :
                     "Connect your PAUSE account in Settings to send messages over the internet.")
            }

            Section {
                DisclosureGroup("Local Wi-Fi connection", isExpanded: $localExpanded) {
                    LabeledContent("Status", value: model.boardConnected ? "Paired" : "Not paired")
                    TextField("Mac board address", text: $model.boardAddress,
                              prompt: Text("http://192.168.1.10:8765"))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    SecureField("Pairing code", text: $model.boardKey)
                        .textInputAutocapitalization(.never)
                    Button("Pair Local Display") {
                        composing = false
                        Task { await model.pairBoard() }
                    }
                    .disabled(model.isWorking)
                    Toggle("Forward limit events", isOn: Binding(
                        get: { model.forwardThresholds },
                        set: { model.setForwardThresholds($0) }
                    ))
                    Button("Send Test Reminder") {
                        Task { await model.sendExampleNudge() }
                    }
                    .disabled(model.isWorking || !model.boardConnected)
                }
            } footer: {
                Text("Advanced: use the older local Mac relay on trusted Wi-Fi. It sends generic reminder events only.")
            }

            if model.status != "Ready when you are." {
                Section {
                    PAUSEStatusNotice(text: model.status)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Board")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { composing = false }
            }
        }
    }
}

/// One canonical layout, shared by preview and action validation.
struct PAUSEBoardLayout {
    let tiles: [String]
    let overflow: Bool

    init(message: String) {
        var rows: [String] = []
        for line in message.uppercased().components(separatedBy: "\n") {
            let letters = Array(line)
            if letters.isEmpty {
                rows.append("")
            } else {
                for offset in stride(from: 0, to: letters.count, by: 22) {
                    rows.append(String(letters[offset..<min(offset + 22, letters.count)]))
                }
            }
        }
        overflow = rows.count > 6
        let visible = Array(rows.prefix(6))
        let top = (6 - visible.count) / 2
        var characters = Array(repeating: " ", count: 132)
        for (rowIndex, line) in visible.enumerated() {
            let letters = Array(line.prefix(22))
            let left = (22 - letters.count) / 2
            for (index, letter) in letters.enumerated() {
                characters[(rowIndex + top) * 22 + left + index] = String(letter)
            }
        }
        tiles = characters
    }
}

/// A miniaturized hardware view, not a generic grid of black cards.
/// Mechanical housing geometry is shared with the web board: ~1.865:1,
/// six rows, 22 recessed wells, printed glyphs and physical flap seams.
struct PAUSEFlapPreview: View {
    let message: String

    private func finish(_ glyph: String) -> [Color] {
        switch glyph {
        case "🟥": return [Color(red: 0.98, green: 0.19, blue: 0.19),
                          Color(red: 0.83, green: 0.12, blue: 0.15)]
        case "🟧": return [Color(red: 1.00, green: 0.51, blue: 0.11),
                          Color(red: 0.90, green: 0.41, blue: 0.07)]
        case "🟨": return [Color(red: 1.00, green: 0.80, blue: 0.13),
                          Color(red: 0.92, green: 0.71, blue: 0.11)]
        case "🟩": return [Color(red: 0.10, green: 0.68, blue: 0.28),
                          Color(red: 0.07, green: 0.54, blue: 0.23)]
        case "🟦": return [Color(red: 0.00, green: 0.62, blue: 0.93),
                          Color(red: 0.03, green: 0.46, blue: 0.80)]
        case "🟪": return [Color(red: 0.66, green: 0.18, blue: 0.77),
                          Color(red: 0.55, green: 0.13, blue: 0.62)]
        default: return [Color(white: 0.18), Color(white: 0.125)]
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = width / 1.865
            let innerWidth = width * 0.86
            let gap = max(1.3, width * 0.0055)
            let rowGap = max(2.2, width * 0.0095)
            let cellWidth = max(2, (innerWidth - 21 * gap) / 22)
            let cellHeight = cellWidth / 0.625
            let tiles = PAUSEBoardLayout(message: message).tiles

            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.16), Color(white: 0.075),
                                 Color(white: 0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
                    .padding(3)

                LazyVGrid(columns: Array(
                    repeating: GridItem(.fixed(cellWidth), spacing: gap),
                    count: 22
                ), spacing: rowGap) {
                    ForEach(tiles.indices, id: \.self) { index in
                        let glyph = tiles[index]
                        let colors = finish(glyph)
                        ZStack {
                            LinearGradient(
                                colors: colors,
                                startPoint: .top, endPoint: .bottom
                            )
                            Rectangle()
                                .fill(Color.black.opacity(0.8))
                                .frame(height: max(0.6, width * 0.0010))
                            if !["🟥","🟧","🟨","🟩","🟦","🟪"].contains(glyph) {
                                Text(glyph)
                                    .font(.custom(
                                        "DMMono-Medium",
                                        size: max(7, cellWidth * 0.74)
                                    ))
                                    .minimumScaleFactor(0.80)
                                    .lineLimit(1)
                                    .foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.93))
                            }
                        }
                        .frame(width: cellWidth, height: cellHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                        .overlay {
                            RoundedRectangle(cornerRadius: 1)
                                .strokeBorder(.black.opacity(0.65), lineWidth: 0.7)
                        }
                    }
                }
                .frame(width: innerWidth)
                .position(x: width / 2, y: height * 0.488)

                Text("PAUSE")
                    .font(.custom("SpaceGrotesk-Bold", size: max(5, width * 0.013)))
                    .tracking(2)
                    .foregroundStyle(Color.black.opacity(0.58))
                    .position(x: width / 2, y: height * 0.946)
            }
            .frame(width: width, height: height)
            .overlay {
                Rectangle()
                    .strokeBorder(Color.black.opacity(0.85), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 12, x: 8, y: 12)
        }
        .aspectRatio(1.865, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Physical split-flap board preview: \(message)")
    }
}
