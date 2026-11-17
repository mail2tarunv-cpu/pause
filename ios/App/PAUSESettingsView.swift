import SwiftUI

struct PAUSESettingsView: View {
    @ObservedObject var model: PAUSEModel
    @ObservedObject private var cloud = PAUSECloud.shared
    @State private var showClearConfirmation = false
    @State private var showDisconnectConfirmation = false
    @State private var cloudConfigurationExpanded = false

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(model.screenTimeAuthorized ? "Allowed" : "Off")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Screen Time", systemImage: "hourglass")
                }
                if !model.screenTimeAuthorized {
                    Button("Allow Screen Time") {
                        Task { await model.authorizeScreenTime() }
                    }
                }
                LabeledContent {
                    Text(model.notificationAuthorized ? "Allowed" : "Off")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
                if !model.notificationAuthorized {
                    Button("Enable Notifications") {
                        Task { await model.requestNotifications() }
                    }
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("PAUSE only monitors selected activity and does not read your messages.")
            }

            Section {
                LabeledContent {
                    Text(cloud.signedIn ? "Signed in" : "Not connected")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Account", systemImage: "icloud")
                }

                if cloud.signedIn {
                    Toggle("Sync check-ins", isOn: Binding(
                        get: { cloud.enabled },
                        set: { cloud.setEnabled($0) }
                    ))
                    Button {
                        Task { await cloud.syncLocalEvents() }
                    } label: {
                        Label("Sync Now", systemImage: "arrow.clockwise")
                    }
                    Button("Sign Out", role: .destructive) { cloud.signOut() }
                } else {
                    TextField("Email address", text: $cloud.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $cloud.password)
                        .textContentType(.password)
                    Button("Sign In") {
                        Task { await cloud.signIn() }
                    }
                    .disabled(cloud.email.isEmpty || cloud.password.isEmpty)
                }

                DisclosureGroup("Server configuration", isExpanded: $cloudConfigurationExpanded) {
                    TextField("Project URL", text: $cloud.projectURL,
                              prompt: Text("https://your-project.supabase.co"))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("Public publishable key", text: $cloud.publishableKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Text(cloud.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("PAUSE Cloud")
            } footer: {
                Text("Cloud sync is optional. Only generic check-in events are sent; the detailed iPhone Screen Time report stays on your device.")
            }

            Section {
                LabeledContent("Local display", value:
                    model.boardConnected ? "Paired" : "Not paired")
                Button("Forget Local Display", role: .destructive) {
                    showDisconnectConfirmation = true
                }
                .disabled(model.boardAddress.isEmpty && model.boardKey.isEmpty)
            } header: {
                Text("Display")
            }

            Section {
                LabeledContent("Recorded check-ins", value: "\(model.recentEvents.count)")
                Button("Clear Check-in History", role: .destructive) {
                    showClearConfirmation = true
                }
                .disabled(model.recentEvents.isEmpty)
            } header: {
                Text("Data & privacy")
            } footer: {
                Text("Removing local history does not delete previously synchronized cloud records.")
            }

            Section {
                LabeledContent("App", value: "PAUSE")
                LabeledContent("Version", value: "0.4")
            } header: {
                Text("About")
            }

            if model.status != "Ready when you are." {
                Section {
                    PAUSEStatusNotice(text: model.status)
                }.listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Delete local check-in history?",
            isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Delete History", role: .destructive) {
                model.clearLocalHistory()
            }
        } message: {
            Text("This only clears PAUSE records on your iPhone.")
        }
        .confirmationDialog("Forget the local display?",
            isPresented: $showDisconnectConfirmation, titleVisibility: .visible) {
            Button("Forget Display", role: .destructive) {
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
