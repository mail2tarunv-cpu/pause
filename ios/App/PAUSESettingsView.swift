import SwiftUI

struct PAUSESettingsView: View {
    @ObservedObject var model: PAUSEModel
    @ObservedObject private var cloud = PAUSECloud.shared
    @State private var showClearConfirmation = false
    @State private var showDisconnectConfirmation = false

    var body: some View {
        Form {
            Section {
                PAUSEInfoRow(
                    symbol: "hand.raised",
                    title: "Your data stays yours",
                    explanation: "PAUSE works without an account. Sharing across devices is optional."
                )
            }
            .listRowBackground(Color.clear)

            Section("Permissions") {
                HStack {
                    Label("Screen Time", systemImage: "hourglass")
                    Spacer()
                    Text(model.screenTimeAuthorized ? "Allowed" : "Off")
                        .foregroundStyle(.secondary)
                }
                if !model.screenTimeAuthorized {
                    Button("Allow Screen Time") {
                        Task { await model.authorizeScreenTime() }
                    }
                }

                HStack {
                    Label("Notifications", systemImage: "bell")
                    Spacer()
                    Text(model.notificationAuthorized ? "Allowed" : "Off")
                        .foregroundStyle(.secondary)
                }
                if !model.notificationAuthorized {
                    Button("Enable notifications") {
                        Task { await model.requestNotifications() }
                    }
                }
            }

            Section {
                LabeledContent("Monitoring") {
                    Label(model.monitoring ? "On" : "Paused",
                          systemImage: model.monitoring ? "checkmark.circle.fill" : "pause.circle")
                        .foregroundStyle(model.monitoring ? Color.green : Color.secondary)
                }
                if model.monitoring {
                    Button("Stop monitoring", role: .destructive) {
                        model.stopMonitoring()
                    }
                }
            } header: {
                Text("Monitoring")
            } footer: {
                Text("PAUSE monitors only selected activity. It does not read your messages or block apps.")
            }

            Section("Connected board") {
                LabeledContent("Local board") {
                    Text(model.boardConnected ? "Paired" : "Not paired")
                        .foregroundStyle(.secondary)
                }
                Button("Forget local board", role: .destructive) {
                    showDisconnectConfirmation = true
                }
                .disabled(model.boardAddress.isEmpty && model.boardKey.isEmpty)
            }

            Section {
                TextField("Project URL", text: $cloud.projectURL,
                          prompt: Text("https://your-project.supabase.co"))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                TextField("Public publishable key", text: $cloud.publishableKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if cloud.signedIn {
                    Toggle("Sync generic threshold events", isOn: Binding(
                        get: { cloud.enabled },
                        set: { cloud.setEnabled($0) }
                    ))
                    Button {
                        Task { await cloud.syncLocalEvents() }
                    } label: {
                        Label("Sync now", systemImage: "arrow.clockwise")
                    }
                    Button("Sign out", role: .destructive) {
                        cloud.signOut()
                    }
                } else {
                    TextField("Email address", text: $cloud.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $cloud.password)
                        .textContentType(.password)
                    Button("Sign in") {
                        Task { await cloud.signIn() }
                    }
                    .disabled(cloud.email.isEmpty || cloud.password.isEmpty)
                }
                Text(cloud.status)
                    .font(PAUSEType.body(.footnote))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Private cloud · Optional")
            } footer: {
                Text("Sync shares only generic reminder events. Apple's raw Screen Time report stays on this iPhone.")
            }

            Section {
                LabeledContent("Local events", value: "\(model.recentEvents.count)")
                Button("Clear check-in history", role: .destructive) {
                    showClearConfirmation = true
                }
                .disabled(model.recentEvents.isEmpty)
            } header: {
                Text("Data & privacy")
            } footer: {
                Text("Clearing PAUSE events does not delete Apple's Screen Time history or previously synced cloud records.")
            }

            Section("About") {
                LabeledContent("App", value: "PAUSE")
                LabeledContent("Version", value: "0.4")
                PAUSEInfoRow(
                    symbol: "info.circle",
                    title: "Built for awareness",
                    explanation: "Reminders currently use rules and templates, not AI-generated advice."
                )
            }

            Section {
                PAUSEStatusNotice(text: model.status)
            }
            .listRowBackground(Color.clear)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(PAUSEPalette.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete local check-in history?",
            isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Delete history", role: .destructive) {
                model.clearLocalHistory()
            }
        } message: {
            Text("Only the PAUSE history on this iPhone will be cleared.")
        }
        .confirmationDialog("Forget the local board?",
            isPresented: $showDisconnectConfirmation, titleVisibility: .visible) {
            Button("Forget board", role: .destructive) {
                model.boardAddress = ""
                model.boardKey = ""
                model.boardConnected = false
                model.saveBoardConnection()
                model.status = "Local board pairing cleared."
            }
        } message: {
            Text("You can pair again from the Board tab.")
        }
    }
}
