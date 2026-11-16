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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("LIVE PREVIEW", systemImage: "square.grid.3x3.fill")
                            .font(PAUSEType.body(.caption2, strong: true))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.65))
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
                        .foregroundStyle(boardLayout.overflow ? .orange : .white.opacity(0.65))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PAUSEPalette.board, in: RoundedRectangle(cornerRadius: 17))
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

            Section("Cloud display") {
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

struct PAUSEFlapPreview: View {
    let message: String

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 2
            let cell = max(5, (proxy.size.width - 21 * gap) / 22)
            let tiles = PAUSEBoardLayout(message: message).tiles

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: gap), count: 22),
                spacing: 3
            ) {
                ForEach(tiles.indices, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(white: 0.19))
                        Rectangle()
                            .fill(.black.opacity(0.55))
                            .frame(height: 1)
                        Text(tiles[index])
                            .font(.custom("DMMono-Medium", size: max(7, cell * 0.60)))

                            .foregroundStyle(.white.opacity(0.94))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                    .frame(height: cell * 1.24)
                }
            }
        }
        .frame(height: 132)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Split-flap board preview: \(message)")
    }
}
