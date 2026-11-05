import SwiftUI
import FamilyControls
import DeviceActivity

@main
struct PAUSECompanionApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var address = ""
    @State private var code = ""
    @State private var category = "social"
    @State private var thresholdMinutes = 20
    @State private var selection = FamilyActivitySelection()
    @State private var picking = false
    @State private var status = "Connect to your PAUSE board to begin."
    @State private var monitoring = false
    @State private var working = false

    private let accent = Color(red: 0.17, green: 0.19, blue: 0.17)
    private let monitorName = DeviceActivityName("pause.selected.daily")
    private let eventName = DeviceActivityEvent.Name("pause.selected.limit")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PAUSE").font(.system(size: 12, weight: .bold))
                            .tracking(4)
                        Text("Make a little\nspace to notice.")
                            .font(.system(size: 35, weight: .medium, design: .rounded))
                            .tracking(-1.8)
                        Text("A companion for the split-flap display. Your app selection stays on your iPhone.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    section("01 / Connect to the board") {
                        TextField("http://192.168.1.10:8765", text: $address)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Mac relay address")
                        SecureField("Pairing key from Mac Terminal", text: $code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Button("Pair with Mac") {
                            working = true
                            persistConnection()
                            Task {
                                do {
                                    try await PAUSETransport.send(action: "ping")
                                    status = "Paired. The Mac is responding."
                                } catch {
                                    status = "Pairing failed: \(error.localizedDescription)"
                                }
                                working = false
                            }
                        }
                        .buttonStyle(PAUSEButtonStyle())
                        .disabled(working)
                    }
                    section("02 / Choose what to monitor") {
                        Button("Allow Screen Time access") {
                            Task {
                                do {
                                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                                    status = "Screen Time authorization granted."
                                } catch {
                                    status = "Authorization failed: \(error.localizedDescription)"
                                }
                            }
                        }.buttonStyle(.bordered)
                        Button {
                            picking = true
                        } label: {
                            HStack {
                                Image(systemName: "app.badge")
                                Text("Choose apps or categories")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .tint(accent)
                        Text("\(selection.applicationTokens.count) apps and \(selection.categoryTokens.count) categories selected")
                            .font(.caption).foregroundStyle(.secondary)
                        Picker("Nudge type", selection: $category) {
                            Text("Social").tag("social")
                            Text("Creative / work").tag("creative")
                            Text("Entertainment").tag("entertainment")
                        }.pickerStyle(.segmented)
                        Stepper("Daily threshold: \(thresholdMinutes) min",
                                value: $thresholdMinutes, in: 5...180, step: 5)
                            .font(.subheadline)
                        Text("Apple monitors cumulative activity for your selected apps during the daily interval. It is not a continuous-session timer.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    section("03 / Begin your experiment") {
                        Button(monitoring ? "Update monitoring" : "Start monitoring") {
                            startMonitoring()
                        }.buttonStyle(PAUSEButtonStyle())
                        Button("Stop monitoring") {
                            DeviceActivityCenter().stopMonitoring([monitorName])
                            monitoring = false
                            status = "Monitoring stopped."
                        }.buttonStyle(.bordered)
                        Button("Send a test nudge") {
                            persistConnection()
                            working = true
                            Task {
                                do {
                                    try await PAUSETransport.send(action: "threshold", category: category)
                                    status = "Test nudge delivered to the board."
                                } catch {
                                    status = "Test failed: \(error.localizedDescription)"
                                }
                                working = false
                            }
                        }.buttonStyle(.bordered).disabled(working)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("STATUS").font(.caption2.bold()).tracking(2)
                        Text(status).font(.subheadline)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 13))
                    Text("PAUSE monitors only the apps you authorize. No app names, messages, browsing history or full usage reports are sent to the Mac—only a threshold category. The devices must share trusted Wi-Fi.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(22)
            }
            .background(Color(red: 0.93, green: 0.92, blue: 0.89))
            .toolbar(.hidden, for: .navigationBar)
            .familyActivityPicker(isPresented: $picking, selection: $selection)
            .onAppear(perform: load)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        do { try await PAUSETransport.flushPending() }
                        catch { status = "A pending nudge will retry when the Mac is reachable." }
                    }
                }
            }
        }
    }

    @ViewBuilder private func section<Content: View>(
        _ heading: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(heading).font(.system(size: 13, weight: .semibold))
            content()
        }
        .padding(18)
        .background(Color(red: 0.975, green: 0.973, blue: 0.96),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private func load() {
        address = PAUSETransport.preferences?.string(forKey: PAUSETransport.bridgeKey) ?? ""
        code = PAUSETransport.preferences?.string(forKey: PAUSETransport.pairingKey) ?? ""
        category = PAUSETransport.preferences?.string(forKey: "selectedCategory") ?? "social"
        thresholdMinutes = PAUSETransport.preferences?.integer(forKey: "selectedMinutes") ?? 20
        if thresholdMinutes < 5 { thresholdMinutes = 20 }
        if let data = PAUSETransport.preferences?.data(forKey: "selection"),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        }
        monitoring = DeviceActivityCenter().activities.contains(monitorName)
        Task { try? await PAUSETransport.flushPending() }
    }

    private func persistConnection() {
        PAUSETransport.configure(address: address, code: code)
    }

    private func startMonitoring() {
        guard !selection.applicationTokens.isEmpty ||
              !selection.categoryTokens.isEmpty ||
              !selection.webDomainTokens.isEmpty else {
            status = "Select at least one app, category, or website first."
            return
        }
        persistConnection()
        PAUSETransport.preferences?.set(category, forKey: "selectedCategory")
        PAUSETransport.preferences?.set(thresholdMinutes, forKey: "selectedMinutes")
        if let data = try? JSONEncoder().encode(selection) {
            PAUSETransport.preferences?.set(data, forKey: "selection")
        }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: thresholdMinutes)
        )
        do {
            DeviceActivityCenter().stopMonitoring([monitorName])
            try DeviceActivityCenter().startMonitoring(
                monitorName, during: schedule, events: [eventName: event]
            )
            monitoring = true
            status = "Monitoring enabled. A generic \(category) nudge is queued when the threshold is reached."
        } catch {
            monitoring = false
            status = "Unable to start monitoring: \(error.localizedDescription)"
        }
    }
}

private struct PAUSEButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(14)
            .foregroundStyle(.white)
            .background(Color(red: 0.17, green: 0.19, blue: 0.17).opacity(configuration.isPressed ? 0.72 : 1),
                        in: RoundedRectangle(cornerRadius: 10))
    }
}
