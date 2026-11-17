import SwiftUI
import AppKit

private enum PAUSEMacSection: String, CaseIterable, Identifiable {
    case overview, activity, browser, cloud, board
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .activity: return "Activity"
        case .browser: return "Browser"
        case .cloud: return "Cloud"
        case .board: return "Board"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .activity: return "chart.bar.xaxis"
        case .browser: return "globe"
        case .cloud: return "icloud"
        case .board: return "rectangle.grid.1x2"
        }
    }
}

struct MacDashboard: View {
    @ObservedObject var activity: MacActivityStore
    @ObservedObject var cloud: MacCloudSync

    @State private var selection: PAUSEMacSection? = .overview
    @State private var showingToken = false
    @State private var showingDelete = false

    private var timeToday: String {
        "\(activity.totalMinutes / 60)h \(activity.totalMinutes % 60)m"
    }

    var body: some View {
        NavigationSplitView {
            List(PAUSEMacSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("PAUSE")
            .frame(minWidth: 174)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    currentSection
                }
                .frame(maxWidth: 880, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(PAUSEMacPalette.paper)
            .navigationTitle(selection?.title ?? "Overview")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activity.isTracking.toggle()
                    } label: {
                        Label(activity.isTracking ? "Pause Tracking" : "Resume Tracking",
                              systemImage: activity.isTracking ? "pause.fill" : "play.fill")
                    }
                    .help(activity.isTracking ? "Pause Mac activity monitoring" : "Resume Mac activity monitoring")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .alert("Delete local activity history?", isPresented: $showingDelete) {
            Button("Delete History", role: .destructive) { activity.clearRecords() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes only the local PAUSE records on this Mac. Previously synchronized cloud summaries are not deleted.")
        }
    }

    @ViewBuilder private var currentSection: some View {
        switch selection ?? .overview {
        case .overview: overview
        case .activity: activityDetails
        case .browser: browserSettings
        case .cloud: cloudSettings
        case .board: boardPreview
        }
    }

    @ViewBuilder private func intro(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            PAUSEMacShapeStamp()
                .padding(.bottom, 6)
            Text(title)
                .font(PAUSEMacType.heading(.largeTitle))
            Text(detail)
                .font(PAUSEMacType.body(.subheadline))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 3)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro("Good to have you here.",
                  "A quieter place to understand your time on this Mac.")

            HStack(alignment: .top, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(timeToday)
                            .font(PAUSEMacType.heading(.largeTitle))
                            .monospacedDigit()
                        Text("Foreground time, excluding idle periods")
                            .font(PAUSEMacType.body(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Active today", systemImage: "clock")
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(activity.foreground)
                            .font(PAUSEMacType.heading(.title3))
                            .lineLimit(2)
                            .frame(minHeight: 40, alignment: .leading)
                        Label(activity.isTracking ? "Tracking locally" : "Monitoring paused",
                              systemImage: activity.isTracking ? "checkmark.circle.fill" : "pause.circle")
                            .font(PAUSEMacType.body(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Right now", systemImage: "circle.dotted")
                }
            }

            categoryGroup

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(activity.isWebsiteConnected ? "Browser paired" : "Browser not paired",
                              systemImage: activity.isWebsiteConnected ? "checkmark.circle.fill" : "globe")
                        Spacer()
                        Button("Set Up") { selection = .browser }
                    }
                    Divider()
                    HStack {
                        Label(cloud.authenticated ? "Cloud account connected" : "Cloud disconnected",
                              systemImage: cloud.authenticated ? "checkmark.icloud" : "icloud")
                        Spacer()
                        Button("Manage") { selection = .cloud }
                    }
                    Text("Local tracking continues without a browser extension or cloud account.")
                        .font(PAUSEMacType.body(.caption))
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text("Connections")
            }
        }
    }

    private var categoryGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                if activity.byCategory.isEmpty {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "chart.bar",
                        description: Text("Keep PAUSE running while you use your Mac.")
                    )
                    .frame(minHeight: 150)
                } else {
                    let total = max(1, activity.todayRecords.reduce(0) { $0 + $1.seconds })
                    ForEach(activity.byCategory, id: \.0) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.0.capitalized)
                                Spacer()
                                Text("\(entry.1 / 60)m")
                                    .font(PAUSEMacType.body())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(entry.1), total: Double(total))
                                .tint(PAUSEMacPalette.tint)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Where your time went", systemImage: "chart.bar.fill")
        }
    }

    private var activityDetails: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro("Activity", "Foreground app and website time recorded on this Mac.")
            categoryGroup

            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    if activity.todayRecords.isEmpty {
                        ContentUnavailableView("No activity recorded", systemImage: "clock")
                            .frame(minHeight: 140)
                    } else {
                        ForEach(activity.todayRecords) { record in
                            HStack(spacing: 12) {
                                Image(systemName: record.kind == "site" ? "globe" : "app")
                                    .frame(width: 22)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.label)
                                        .lineLimit(1)
                                        .font(PAUSEMacType.body(.body, strong: true))
                                    Text(record.category.capitalized)
                                        .font(PAUSEMacType.body(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 12)
                                Text("\(record.seconds / 60)m")
                                    .font(PAUSEMacType.body())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 9)
                            Divider()
                        }
                    }
                }
            } label: {
                Label("Applications and websites", systemImage: "list.bullet")
            }

            HStack {
                Label("Stored only on this Mac for up to seven days.",
                      systemImage: "lock.shield")
                    .font(PAUSEMacType.body(.caption))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear Local History", role: .destructive) {
                    showingDelete = true
                }
                .disabled(activity.records.isEmpty)
            }
        }
    }

    private var browserSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro("Browser", "Connect Chrome or a compatible extension for website-level time.")
            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    LabeledContent("Status", value: activity.isWebsiteConnected ? "Connected" : "Not paired")
                    LabeledContent("Local listener", value: activity.bridgeStatus)
                    LabeledContent("Latest website", value: activity.lastWebsite)
                    Divider()
                    Text("Browser pairing code")
                        .font(PAUSEMacType.heading(.headline))
                    HStack {
                        Group {
                            if showingToken {
                                Text(activity.browserPairingCode)
                                    .font(PAUSEMacType.body())
                                    .textSelection(.enabled)
                            } else {
                                Text("•••• •••• •••• •••• •••• ••••")
                                    .font(PAUSEMacType.body())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button(showingToken ? "Hide" : "Show") {
                            showingToken.toggle()
                        }
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(activity.browserPairingCode, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button("Rotate") { activity.resetBrowserToken() }
                    }
                }
                .padding(.vertical, 5)
            } label: {
                Label("Local pairing", systemImage: "lock")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("1. Open chrome://extensions and enable Developer mode.",
                          systemImage: "1.circle")
                    Label("2. Choose Load unpacked and select browser-extension/.",
                          systemImage: "2.circle")
                    Label("3. Paste the pairing code in the extension popup.",
                          systemImage: "3.circle")
                    Text("The extension sends only active domains, never full URLs or page titles.")
                        .font(PAUSEMacType.body(.caption))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text("Set up extension")
            }
        }
    }

    private var cloudSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro("Cloud", "Private, opt-in synchronization between your PAUSE devices.")
            GroupBox {
                Form {
                    TextField("Project URL", text: $cloud.projectURL,
                              prompt: Text("https://your-project.supabase.co"))
                    TextField("Publishable key", text: $cloud.publishableKey)
                    if !cloud.authenticated {
                        TextField("Email", text: $cloud.email)
                        SecureField("Password", text: $cloud.password)
                        Button("Sign In") {
                            Task { await cloud.signIn() }
                        }
                        .disabled(cloud.email.isEmpty || cloud.password.isEmpty)
                    } else {
                        LabeledContent("Account", value: "Signed in")
                        Toggle("Sync category totals and board messages", isOn: Binding(
                            get: { cloud.syncEnabled },
                            set: { cloud.setSyncEnabled($0) }
                        ))
                        Button("Sign Out") { cloud.signOut() }
                    }
                }
                .formStyle(.grouped)
                Text(cloud.status)
                    .font(PAUSEMacType.body(.caption))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } label: {
                Label("Account & synchronization", systemImage: "icloud")
            }

            Label("Only daily category totals leave this Mac with your permission. App names and website domains are never uploaded.",
                  systemImage: "hand.raised")
                .font(PAUSEMacType.body(.callout))
                .foregroundStyle(.secondary)
        }
    }

    private var boardPreview: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro("Board", "Your ambient message, carried across devices.")
            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    MacBoardPreview(message: activity.cloudBoardMessage ??
                        "🟦 🟨 🟧 🟦 🟨 🟧 🟦 🟨 🟧 🟦 🟨 \n 🟩 🟥 🟪 🟩 🟥 🟪 🟩 🟥 🟪 🟩 🟥\n🟧    LESS SCREEN     🟦\n🟩     MORE LIFE      🟥\n🟨 🟧 🟦 🟨 🟧 🟦 🟨 🟧 🟦 🟨 🟧 \n 🟪 🟩 🟥 🟪 🟩 🟥 🟪 🟩 🟥 🟪 🟩")
                    HStack {
                        Label(cloud.syncEnabled ? "Cloud polling enabled" : "Local preview",
                              systemImage: "rectangle.on.rectangle")
                            .font(PAUSEMacType.body(.callout))
                        Spacer()
                        Text(cloud.syncEnabled ? "Refreshes every ~30 sec" : "Sign in to connect")
                            .font(PAUSEMacType.body(.caption))
                            .foregroundStyle(.secondary)
                    }
                    Text("The native Mac preview mirrors your latest authenticated board message. To send a message, use the PAUSE iPhone app or cloud controller.")
                        .font(PAUSEMacType.body(.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } label: {
                Text("PAUSE display")
            }
            if !cloud.authenticated {
                Button("Connect a Cloud Account") { selection = .cloud }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct MacBoardPreview: View {
    let message: String

    private var characters: [String] {
        var rows: [String] = []
        for line in message.uppercased().components(separatedBy: "\n") {
            let chars = Array(line)
            if chars.isEmpty { rows.append(""); continue }
            for offset in stride(from: 0, to: chars.count, by: 22) {
                rows.append(String(chars[offset..<min(offset + 22, chars.count)]))
            }
        }
        let active = Array(rows.prefix(6))
        var tiles = Array(repeating: " ", count: 132)
        for (row, line) in active.enumerated() {
            let chars = Array(line.prefix(22))
            for (col, glyph) in chars.enumerated() {
                let index = (row + (6 - active.count) / 2) * 22
                            + (22 - chars.count) / 2 + col
                tiles[index] = String(glyph)
            }
        }
        return tiles
    }

    private func finish(_ glyph: String) -> [Color] {
        switch glyph {
        case "🟥": return [Color(red: 0.98, green: 0.19, blue: 0.19),
                          Color(red: 0.83, green: 0.12, blue: 0.15)]
        case "🟧": return [Color(red: 1, green: 0.51, blue: 0.11),
                          Color(red: 0.90, green: 0.41, blue: 0.07)]
        case "🟨": return [Color(red: 1, green: 0.80, blue: 0.13),
                          Color(red: 0.92, green: 0.71, blue: 0.11)]
        case "🟩": return [Color(red: 0.10, green: 0.68, blue: 0.28),
                          Color(red: 0.07, green: 0.54, blue: 0.23)]
        case "🟦": return [Color(red: 0, green: 0.62, blue: 0.93),
                          Color(red: 0.03, green: 0.46, blue: 0.80)]
        case "🟪": return [Color(red: 0.66, green: 0.18, blue: 0.77),
                          Color(red: 0.55, green: 0.13, blue: 0.62)]
        default: return [Color(white: 0.18), Color(white: 0.125)]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = width / 1.865
            let gridWidth = width * 0.86
            let gap = max(2, width * 0.0055)
            let rowGap = max(3, width * 0.0095)
            let cellWidth = max(3, (gridWidth - gap * 21) / 22)
            let cellHeight = cellWidth / 0.625
            let tiles = characters

            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.16),
                                 Color(white: 0.075),
                                 Color(white: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    .padding(5)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(cellWidth), spacing: gap),
                        count: 22
                    ), spacing: rowGap
                ) {
                    ForEach(tiles.indices, id: \.self) { index in
                        let glyph = tiles[index]
                        ZStack {
                            LinearGradient(
                                colors: finish(glyph),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            Rectangle()
                                .fill(Color.black.opacity(0.85))
                                .frame(height: max(0.6, width * 0.0010))
                            if !["🟥","🟧","🟨","🟩","🟦","🟪"].contains(glyph) {
                                Text(glyph)
                                    .font(.custom(
                                        "DMMono-Medium",
                                        size: max(8, cellWidth * 0.74)
                                    ))
                                    .minimumScaleFactor(0.80)
                                    .lineLimit(1)
                                    .foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.93))
                            }
                        }
                        .frame(width: cellWidth, height: cellHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 1.5)
                                .strokeBorder(.black.opacity(0.7), lineWidth: 1)
                        }
                    }
                }
                .frame(width: gridWidth)
                .position(x: width / 2, y: height * 0.485)

                Text("PAUSE")
                    .font(.custom("SpaceGrotesk-Bold",
                                  size: max(7, width * 0.012)))
                    .tracking(3)
                    .foregroundStyle(Color.black.opacity(0.62))
                    .position(x: width / 2, y: height * 0.943)
            }
            .frame(width: width, height: height)
            .overlay { Rectangle().strokeBorder(Color.black, lineWidth: 1) }
            .shadow(color: .black.opacity(0.25), radius: 17, x: 11, y: 16)
        }
        .aspectRatio(1.865, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PAUSE physical split-flap preview: \(message)")
    }
}
