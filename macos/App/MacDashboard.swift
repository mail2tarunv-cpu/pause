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
            Text(title)
                .font(.largeTitle.weight(.semibold))
            Text(detail)
                .foregroundStyle(.secondary)
                .font(.body)
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
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text("Foreground time, excluding idle periods")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Active today", systemImage: "clock")
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(activity.foreground)
                            .font(.title3.weight(.medium))
                            .lineLimit(2)
                            .frame(minHeight: 40, alignment: .leading)
                        Label(activity.isTracking ? "Tracking locally" : "Monitoring paused",
                              systemImage: activity.isTracking ? "checkmark.circle.fill" : "pause.circle")
                            .font(.caption)
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
                        .font(.caption)
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
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(entry.1), total: Double(total))
                                .tint(.accentColor)
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
                                        .font(.body.weight(.medium))
                                    Text(record.category.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 12)
                                Text("\(record.seconds / 60)m")
                                    .font(.body.monospacedDigit())
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
                    .font(.caption)
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
                        .font(.headline)
                    HStack {
                        Group {
                            if showingToken {
                                Text(activity.browserPairingCode)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            } else {
                                Text("•••• •••• •••• •••• •••• ••••")
                                    .font(.body)
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
                        .font(.caption)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } label: {
                Label("Account & synchronization", systemImage: "icloud")
            }

            Label("Only daily category totals leave this Mac with your permission. App names and website domains are never uploaded.",
                  systemImage: "hand.raised")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var boardPreview: some View {
        VStack(alignment: .leading, spacing: 20) {
            intro("Board", "Your ambient message, carried across devices.")
            GroupBox {
                VStack(alignment: .leading, spacing: 15) {
                    MacBoardPreview(message: activity.cloudBoardMessage ??
                        "A LITTLE SPACE\nTO NOTICE WHAT MATTERS")
                    HStack {
                        Label(cloud.syncEnabled ? "Cloud polling enabled" : "Local preview",
                              systemImage: "rectangle.on.rectangle")
                            .font(.callout)
                        Spacer()
                        Text(cloud.syncEnabled ? "Refreshes every ~30 sec" : "Sign in to connect")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("The native Mac preview mirrors your latest authenticated board message. To send a message, use the PAUSE iPhone app or cloud controller.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } label: {
                Text("Vestaboard")
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
        var lines: [String] = []
        for line in message.uppercased().components(separatedBy: "\n") {
            let array = Array(line)
            if array.isEmpty {
                lines.append("")
            } else {
                for offset in stride(from: 0, to: array.count, by: 22) {
                    lines.append(String(array[offset..<min(offset + 22, array.count)]))
                }
            }
        }
        let rows = Array(lines.prefix(6))
        var cells = Array(repeating: " ", count: 132)
        for (row, line) in rows.enumerated() {
            let chars = Array(line.prefix(22))
            let left = (22 - chars.count) / 2
            for (col, character) in chars.enumerated() {
                cells[(row + (6 - rows.count) / 2) * 22 + left + col] = String(character)
            }
        }
        return cells
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 2), count: 22),
            spacing: 3
        ) {
            ForEach(characters.indices, id: \.self) { index in
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.19))
                    Text(characters[index])
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                }
                .frame(height: 20)
            }
        }
        .padding(16)
        .background(Color(white: 0.09), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vestaboard preview: \(message)")
    }
}
