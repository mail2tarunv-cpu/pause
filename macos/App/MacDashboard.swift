import SwiftUI
import AppKit

struct MacDashboard: View {
    @ObservedObject var activity: MacActivityStore
    @ObservedObject var cloud: MacCloudSync
    @State private var showingToken = false
    @State private var showingDelete = false

    private let paper = Color(red: 0.965, green: 0.961, blue: 0.944)
    private let ink = Color(red: 0.14, green: 0.15, blue: 0.14)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack {
                    Text("PAUSE").tracking(4).font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text("MAC COMPANION  /  0.1")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your attention,\nback in view.")
                        .font(.system(size: 43, weight: .medium, design: .rounded))
                        .tracking(-2)
                    Text("Local Mac activity, a connected browser, and a quieter board.")
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 12) {
                    card {
                        kicker("ACTIVE TIME TODAY")
                        Text("\(activity.totalMinutes / 60)h \(activity.totalMinutes % 60)m")
                            .font(.system(size: 36, weight: .medium, design: .rounded))
                        Text("Foreground time excluding idle periods")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    card {
                        kicker("RIGHT NOW")
                        Text(activity.foreground).font(.title3)
                            .lineLimit(2)
                            .frame(minHeight: 43, alignment: .leading)
                        Text(activity.isTracking ? "Tracking locally" : "Monitoring paused")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                card {
                    HStack {
                        kicker("LOCAL APPLICATION ACTIVITY")
                        Spacer()
                        Toggle("Tracking", isOn: $activity.isTracking)
                            .toggleStyle(.switch).labelsHidden()
                    }
                    ForEach(activity.byCategory, id: \.0) { entry in
                        HStack(spacing: 10) {
                            Text(entry.0.capitalized).frame(width: 105, alignment: .leading)
                            GeometryReader { geo in
                                Capsule().fill(ink.opacity(0.06))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(ink.opacity(0.74))
                                            .frame(width: geo.size.width * CGFloat(entry.1) /
                                                   CGFloat(max(1, activity.todayRecords.reduce(0) { $0 + $1.seconds })))
                                    }
                            }
                            .frame(height: 8)
                            Text("\(entry.1 / 60)m")
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 40, alignment: .trailing)
                        }.font(.caption)
                    }
                    if activity.byCategory.isEmpty {
                        Text("No activity recorded yet. Keep PAUSE running while you work.")
                            .foregroundStyle(.secondary).font(.caption)
                    }

                    if !activity.todayRecords.isEmpty {
                        Divider()
                        kicker("TOP APPLICATIONS / WEBSITES")
                        ForEach(Array(activity.todayRecords.prefix(8))) { record in
                            HStack {
                                Text(record.label).lineLimit(1)
                                Spacer()
                                Text("\(record.seconds / 60)m")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }.font(.caption)
                        }
                    }
                    HStack {
                        Text("No titles, screenshots, keystrokes or URL paths are recorded.")
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear local history") { showingDelete = true }
                            .buttonStyle(.link)
                    }
                }

                card {
                    HStack {
                        kicker("BROWSER EXTENSION")
                        Spacer()
                        Text(activity.isWebsiteConnected ? "Connected" : "Not yet paired")
                            .foregroundStyle(activity.isWebsiteConnected ? .green : .secondary)
                            .font(.caption)
                    }
                    Text(activity.bridgeStatus).font(.caption)
                    Text("Last site: \(activity.lastWebsite)")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        if showingToken {
                            Text(activity.browserPairingCode)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text("Pairing code hidden")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(showingToken ? "Hide" : "Show") { showingToken.toggle() }
                        Button("Copy code") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(activity.browserPairingCode, forType: .string)
                        }
                        Button("Rotate") { activity.resetBrowserToken() }
                    }
                    Text("Install browser-extension/ in Chrome → Extensions → Developer mode → Load unpacked. Paste this pairing code in its popup.")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                card {
                    HStack {
                        kicker("PRIVATE CROSS-DEVICE SYNC")
                        Spacer()
                        Text(cloud.status).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text("Only daily category totals are uploaded when you opt in. Detailed app and website records remain on this Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        TextField("https://your-project.supabase.co", text: $cloud.projectURL)
                            .textFieldStyle(.roundedBorder)
                        TextField("Public publishable key", text: $cloud.publishableKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        TextField("Account email", text: $cloud.email)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Password", text: $cloud.password)
                            .textFieldStyle(.roundedBorder)
                        Button("Sign in") { Task { await cloud.signIn() } }
                            .disabled(cloud.authenticated)
                        if cloud.authenticated {
                            Button("Sign out") { cloud.signOut() }
                        }
                    }
                    HStack {
                        Toggle(isOn: Binding(
                            get: { cloud.syncEnabled },
                            set: { cloud.setSyncEnabled($0) }
                        )) {
                            Text("Sync category totals and board messages")
                        }
                        .disabled(!cloud.authenticated)
                        Spacer()
                    }
                }

                card {
                    kicker("CONNECTED VESTABOARD")
                    Text("This board mirrors the latest message sent to your PAUSE account.")
                        .font(.caption).foregroundStyle(.secondary)
                    MacBoardPreview(message: activity.cloudBoardMessage ??
                        "THE SPACE BETWEEN\nIS YOURS TO KEEP")
                    Text(cloud.syncEnabled ?
                         "Board messages refresh approximately every 30 seconds." :
                         "Sign in and enable cloud sync to receive messages.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text("PAUSE works locally without cloud configuration. iPhone Screen Time has its own Apple-protected data access rules.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 14)
            }
            .padding(30)
        }
        .background(paper)
        .foregroundStyle(ink)
        .alert("Delete your local Mac activity?", isPresented: $showingDelete) {
            Button("Delete", role: .destructive) { activity.clearRecords() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only clears PAUSE data stored on this Mac. Any already synced category totals must be deleted separately from your cloud account.")
        }
    }

    @ViewBuilder private func kicker(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.2).foregroundStyle(.secondary)
    }

    @ViewBuilder private func card<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) { content() }
            .padding(19)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct MacBoardPreview: View {
    let message: String

    private var characters: [String] {
        var lines: [String] = []
        for line in message.uppercased().components(separatedBy: "\n") {
            if line.isEmpty { lines.append(""); continue }
            let tokens = Array(line)
            for from in stride(from: 0, to: tokens.count, by: 22) {
                lines.append(String(tokens[from..<min(from + 22, tokens.count)]))
            }
        }
        let displayed = Array(lines.prefix(6))
        var tiles = Array(repeating: " ", count: 132)
        let start = (6 - displayed.count) / 2
        for (i, line) in displayed.enumerated() {
            let chars = Array(line.prefix(22))
            for (j, char) in chars.enumerated() {
                tiles[(start + i) * 22 + (22 - chars.count) / 2 + j] = String(char)
            }
        }
        return tiles
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 2), count: 22), spacing: 3) {
            ForEach(characters.indices, id: \.self) { i in
                ZStack {
                    RoundedRectangle(cornerRadius: 1).fill(Color(white: 0.19))
                    Text(characters[i])
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .minimumScaleFactor(0.4).lineLimit(1)
                        .foregroundStyle(.white)
                }.frame(height: 19)
            }
        }
        .padding(13)
        .background(Color(white: 0.075), in: RoundedRectangle(cornerRadius: 9))
    }
}
