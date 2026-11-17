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
    var symbol: String {
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

    private var minutes: String {
        let total = activity.totalMinutes
        return total >= 60 ? "\(total / 60) hr \(total % 60) min" : "\(total) min"
    }

    var body: some View {
        NavigationSplitView {
            List(PAUSEMacSection.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
                    .padding(.vertical, 3)
            }
            .listStyle(.sidebar)
            .navigationTitle("PAUSE")
            .navigationSplitViewColumnWidth(min: 178, ideal: 206, max: 250)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    currentSection
                }
                .frame(maxWidth: 880, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(selection?.title ?? "Overview")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activity.isTracking.toggle()
                        activity.persist()
                    } label: {
                        Label(activity.isTracking ? "Pause tracking" : "Resume tracking",
                              systemImage: activity.isTracking ? "pause.fill" : "play.fill")
                    }
                    .help(activity.isTracking ? "Pause activity tracking" : "Resume activity tracking")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .alert("Delete local activity?", isPresented: $showingDelete) {
            Button("Delete History", role: .destructive) { activity.clearRecords() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes records on this Mac only. Previously synced cloud totals are not deleted.")
        }
    }

    @ViewBuilder private var currentSection: some View {
        switch selection ?? .overview {
        case .overview: overview
        case .activity: activityView
        case .browser: browserView
        case .cloud: cloudView
        case .board: boardView
        }
    }

    @ViewBuilder private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                heading("Overview", subtitle: "Your Mac activity today")
                Spacer()
                Label(activity.isTracking ? "Tracking" : "Paused",
                      systemImage: activity.isTracking ? "checkmark.circle.fill" : "pause.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(activity.isTracking ? Color.green : Color.secondary)
                    .padding(.top, 8)
            }
            HStack(spacing: 14) {
                metricCard("Active time", value: minutes,
                           subtitle: "Foreground use", icon: "clock")
                metricCard("Current activity", value: activity.foreground,
                           subtitle: activity.isTracking ? "Live on this Mac" : "Tracking paused",
                           icon: "macwindow")
            }
            categoryPanel
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Recent activity", caption: "Today")
                PAUSEMacPanel {
                    if activity.todayRecords.isEmpty {
                        emptyRow("No activity recorded",
                                 detail: "Switch to another app and use your Mac to begin tracking.",
                                 icon: "clock.arrow.circlepath")
                    } else {
                        ForEach(Array(activity.todayRecords.prefix(4))) { record in
                            recordRow(record)
                            if record.id != activity.todayRecords.prefix(4).last?.id {
                                Divider()
                            }
                        }
                        HStack {
                            Spacer()
                            Button("See all activity") { selection = .activity }
                                .buttonStyle(.link)
                        }.padding(.top, 4)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Connections")
                PAUSEMacPanel {
                    connectionRow("Browser extension",
                        detail: activity.isWebsiteConnected ? "Connected" : "Not paired",
                        icon: "globe", action: "Set Up", target: .browser)
                    Divider()
                    connectionRow("PAUSE Cloud",
                        detail: cloud.authenticated ? "Signed in" : "Not connected",
                        icon: "icloud", action: "Manage", target: .cloud)
                }
            }
        }
    }

    @ViewBuilder private func metricCard(_ title: String, value: String,
                                          subtitle: String, icon: String) -> some View {
        PAUSEMacPanel {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(title == "Active time"
                      ? .system(size: 34, weight: .semibold, design: .rounded)
                      : .system(size: 19, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .accessibilityAddTraits(.updatesFrequently)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Activity by category")
            PAUSEMacPanel {
                if activity.byCategory.isEmpty {
                    emptyRow("Nothing to show yet",
                             detail: "Activity will appear here once PAUSE has recorded a few minutes.",
                             icon: "chart.bar")
                } else {
                    let total = max(1, activity.todayRecords.reduce(0) { $0 + $1.seconds })
                    ForEach(activity.byCategory, id: \.0) { entry in
                        HStack(spacing: 16) {
                            Text(entry.0.capitalized)
                                .font(.subheadline.weight(.medium))
                                .frame(width: 118, alignment: .leading)
                            ProgressView(value: Double(entry.1), total: Double(total))
                                .tint(.accentColor)
                            Text("\(entry.1 / 60) min")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .trailing)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    @ViewBuilder private func sectionHeading(_ title: String, caption: String? = nil) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let caption { Text(caption).font(.caption).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private func emptyRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tertiary)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder private func recordRow(_ record: ActivityRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind == "site" ? "globe" : "app")
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.label).font(.body.weight(.medium)).lineLimit(1)
                Text(record.category.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text("\(record.seconds / 60) min")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder private func connectionRow(
        _ title: String, detail: String, icon: String,
        action: String, target: PAUSEMacSection
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action) { selection = target }
                .controlSize(.regular)
        }
        .padding(.vertical, 5)
    }

    private var activityView: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Activity", subtitle: "Foreground time recorded locally on your Mac.")
            categoryPanel
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Applications and websites")
                PAUSEMacPanel {
                    if activity.todayRecords.isEmpty {
                        emptyRow("No activity yet",
                                 detail: "Leave PAUSE running while you work in another application.",
                                 icon: "macwindow")
                    } else {
                        ForEach(activity.todayRecords) { record in
                            recordRow(record)
                            if record.id != activity.todayRecords.last?.id { Divider() }
                        }
                    }
                }
            }
            HStack(alignment: .center) {
                Label("Up to seven days of history stays on this Mac.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 16)
                Button("Clear History", role: .destructive) { showingDelete = true }
                    .disabled(activity.records.isEmpty)
            }
        }
    }

    private var browserView: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Browser", subtitle: "Track active websites using a local browser extension.")
            PAUSEMacPanel {
                LabeledContent("Connection", value:
                    activity.isWebsiteConnected ? "Connected" : "Not paired")
                Divider()
                LabeledContent("Local listener", value: activity.bridgeStatus)
                Divider()
                LabeledContent("Last website", value: activity.lastWebsite)
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Pairing")
                PAUSEMacPanel {
                    Text("Pairing code")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 12) {
                        if showingToken {
                            Text(activity.browserPairingCode)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Label("Hidden", systemImage: "lock.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button {
                            showingToken.toggle()
                        } label: {
                            Label(showingToken ? "Hide" : "Reveal",
                                  systemImage: showingToken ? "eye.slash" : "eye")
                        }
                    }
                    HStack(spacing: 10) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(activity.browserPairingCode, forType: .string)
                        } label: {
                            Label("Copy Code", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            activity.resetBrowserToken()
                            showingToken = false
                        } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                    }
                    Text("The code only pairs a browser on this Mac. Treat it like a password.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Set up Chrome")
                PAUSEMacPanel {
                    instruction("1", "Open chrome://extensions and turn on Developer mode.")
                    Divider()
                    instruction("2", "Choose Load unpacked and select the browser-extension folder.")
                    Divider()
                    instruction("3", "Paste the pairing code in PAUSE's browser popup.")
                }
            }
            Label("Only active website domains are shared locally. No page contents or full URLs.",
                  systemImage: "hand.raised")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func instruction(_ number: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(detail)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 4)
    }

    private var cloudView: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Cloud", subtitle: "Optional synchronization between your PAUSE devices.")
            PAUSEMacPanel {
                HStack {
                    Label("PAUSE Cloud", systemImage: "icloud")
                        .font(.headline)
                    Spacer()
                    Text(cloud.authenticated ? "Signed in" : "Not connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Project URL")
                            .frame(width: 112, alignment: .leading)
                        TextField("https://your-project.supabase.co", text: $cloud.projectURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Public API key")
                            .frame(width: 112, alignment: .leading)
                        TextField("Publishable key", text: $cloud.publishableKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    if !cloud.authenticated {
                        HStack {
                            Text("Email")
                                .frame(width: 112, alignment: .leading)
                            TextField("Email address", text: $cloud.email)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Password")
                                .frame(width: 112, alignment: .leading)
                            SecureField("Password", text: $cloud.password)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Spacer()
                            Button("Sign In") { Task { await cloud.signIn() } }
                                .buttonStyle(.borderedProminent)
                                .disabled(cloud.email.isEmpty || cloud.password.isEmpty)
                        }
                    } else {
                        Toggle("Sync daily category totals and board messages", isOn: Binding(
                            get: { cloud.syncEnabled },
                            set: { cloud.setSyncEnabled($0) }
                        ))
                        HStack {
                            Spacer()
                            Button("Sign Out") { cloud.signOut() }
                        }
                    }
                }
                Text(cloud.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label("App names and websites stay on this Mac. When enabled, only daily category totals are uploaded.",
                  systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var boardView: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Board", subtitle: "The latest message on your ambient display.")
            PAUSEMacPanel {
                MacBoardPreview(message: activity.cloudBoardMessage ??
                    "🟦 🟨 🟧 🟦 🟨 🟧 🟦 🟨 🟧 🟦 🟨 \n 🟩 🟥 🟪 🟩 🟥 🟪 🟩 🟥 🟪 🟩 🟥\n🟧    LESS SCREEN     🟦\n🟩     MORE LIFE      🟥\n🟨 🟧 🟦 🟨 🟧 🟦 🟨 🟧 🟦 🟨 🟧 \n 🟪 🟩 🟥 🟪 🟩 🟥 🟪 🟩 🟥 🟪 🟩"))
                HStack {
                    Label(cloud.syncEnabled ? "Cloud sync enabled" : "Preview only",
                          systemImage: "rectangle.on.rectangle")
                        .font(.subheadline)
                    Spacer()
                    if !cloud.authenticated {
                        Button("Connect Cloud") { selection = .cloud }
                    }
                }
                Text("Messages can be sent from the iPhone app or cloud controller. Cloud connection is optional.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// One consistent material and padding rhythm for Mac content.
private struct PAUSEMacPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 1)
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
