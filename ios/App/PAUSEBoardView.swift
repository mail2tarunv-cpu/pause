import SwiftUI

struct PAUSEBoardView: View {
    @ObservedObject var model: PAUSEModel
    @ObservedObject private var cloud = PAUSECloud.shared
    @FocusState private var composing: Bool

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
                PAUSEIntro(title: "Your message, out in the open.",
                           subtitle: "Make a little room for the thought that matters.",
                           symbol: "rectangle.grid.1x2")
            }
            .listRowBackground(Color.clear)

            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("LIVE PREVIEW", systemImage: "square.grid.3x3.fill")
                            .font(PAUSEType.body(.caption2, strong: true))
                            .tracking(1)
                            .foregroundStyle(PAUSEPalette.secondary)
                        Spacer()
                        Text("6 × 22")
                            .font(PAUSEType.body(.caption))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    PAUSEFlapPreview(message: model.boardDraft)
                    Text(boardLayout.overflow ?
                         "Message exceeds six rows. Shorten it to send." :
                         "Your message, exactly as it fits on the board.")
                        .font(PAUSEType.body(.caption))
                        .foregroundStyle(boardLayout.overflow ? PAUSEPalette.orange : PAUSEPalette.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PAUSEPalette.surface, in: RoundedRectangle(cornerRadius: 17))
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                TextEditor(text: $model.boardDraft)
                    .font(PAUSEType.body())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .scrollContentBackground(.hidden)
                    .frame(height: 126)
                    .focused($composing)
                    .accessibilityLabel("Board message")
                    .onChange(of: model.boardDraft) { _, value in
                        if value.count > 280 {
                            model.boardDraft = String(value.prefix(280))
                        }
                    }
                HStack {
                    Text("Uppercase · 22 characters per row")
                    Spacer()
                    Text("\(model.boardDraft.count) / 280")
                        .monospacedDigit()
                }
                .font(PAUSEType.body(.caption))
                .foregroundStyle(.secondary)
            } header: {
                Text("Compose")
            } footer: {
                Text("Each row is centered. Extra lines are not silently cut off.")
            }

            Section {
                HStack {
                    Label("Connected account", systemImage: "icloud")
                    Spacer()
                    Text(cloud.signedIn ? "Signed in" : "Not connected")
                        .foregroundStyle(.secondary)
                }
                Button {
                    composing = false
                    Task { await cloud.sendBoard(model.boardDraft) }
                } label: {
                    Label("Send message over cloud", systemImage: "paperplane.fill")
                }
                .disabled(!cloud.signedIn || !canSend)
                Button(role: .destructive) {
                    Task { await cloud.sendBoard(nil) }
                } label: {
                    Label("Clear cloud display", systemImage: "xmark.circle")
                }
                .disabled(!cloud.signedIn)
                Text(cloud.status)
                    .font(PAUSEType.body(.footnote))
                    .foregroundStyle(.secondary)
            } header: {
                PAUSESectionHeading(title: "Cloud display")
            }

            Section {
                LabeledContent("Connection") {
                    Text(model.boardConnected ? "Paired" : "Not paired")
                        .foregroundStyle(.secondary)
                }
                TextField("Mac board address", text: $model.boardAddress,
                          prompt: Text("http://192.168.1.10:8765"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Pairing code", text: $model.boardKey)
                    .textInputAutocapitalization(.never)
                Button("Pair local display") {
                    composing = false
                    Task { await model.pairBoard() }
                }
                .disabled(model.isWorking)
                Toggle("Forward generic limit events", isOn: Binding(
                    get: { model.forwardThresholds },
                    set: { model.setForwardThresholds($0) }
                ))
            } header: {
                Text("Local display · Optional")
            } footer: {
                Text("For the older Mac relay on trusted Wi-Fi. Only generic reminder categories are forwarded, never app identities or Screen Time reports.")
            }

            Section {
                Label(model.category.title + " check-in",
                      systemImage: model.category.icon)
                    .foregroundStyle(.secondary)
                Button("Send simulated reminder") {
                    Task { await model.sendExampleNudge() }
                }
                .disabled(model.isWorking || !model.boardConnected)
            } header: {
                Text("Try a reminder")
            } footer: {
                Text("A test message is not measured Screen Time.")
            }

            Section {
                PAUSEStatusNotice(text: model.status)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PAUSEPalette.background)
        .navigationTitle("Board")
        .navigationBarTitleDisplayMode(.inline)
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
                                .frame(height: max(1, width * 0.0015))
                            if !["🟥","🟧","🟨","🟩","🟦","🟪"].contains(glyph) {
                                Text(glyph)
                                    .font(.custom(
                                        "DMMono-Medium",
                                        size: max(4, cellWidth * 0.63)
                                    ))
                                    .minimumScaleFactor(0.55)
                                    .lineLimit(1)
                                    .foregroundStyle(Color(white: 0.94))
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
