import SwiftUI
import FamilyControls

struct PAUSERulesView: View {
    @ObservedObject var model: PAUSEModel
    @State private var choosingApps = false

    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("A gentle reminder").font(.body.weight(.medium))
                        Text("Choose which activities to watch and when to check in.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "hourglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                LabeledContent {
                    Text(model.screenTimeAuthorized ? "Allowed" : "Not allowed")
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
                Text("Apple keeps the selected apps and their Screen Time reports private.")
            }

            Section {
                Button {
                    choosingApps = true
                } label: {
                    HStack(spacing: 10) {
                        Label("Choose Apps and Websites", systemImage: "square.grid.2x2")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(!model.screenTimeAuthorized)
                LabeledContent("Selected", value: "\(model.selectionCount) items")
            } header: {
                Text("Monitored activity")
            } footer: {
                Text("Only activity you select counts toward your daily threshold.")
            }

            Section {
                Stepper(value: $model.thresholdMinutes, in: 5...240, step: 5) {
                    LabeledContent("Daily limit") {
                        Text("\(model.thresholdMinutes) min")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
                Picker("Reminder style", selection: $model.category) {
                    ForEach(PAUSECategory.allCases) { category in
                        Label(category.title, systemImage: category.icon).tag(category)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("Check-in")
            } footer: {
                Text("The limit counts total use across the day, not a continuous session.")
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.category.title + " check-in")
                            .font(.body.weight(.medium))
                        Text(model.category.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: model.category.icon)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Reminder preview")
            }

            Section {
                Button {
                    model.startMonitoring()
                } label: {
                    Label(model.monitoring ? "Update Monitoring" : "Start Monitoring",
                          systemImage: model.monitoring ? "checkmark.circle" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.screenTimeAuthorized || !model.hasSelection)

                if model.monitoring {
                    Button("Stop Monitoring", role: .destructive) {
                        model.stopMonitoring()
                    }
                    .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(model.monitoring ? "Monitoring is active." : "Monitoring is currently paused.")
            }

            if model.status != "Ready when you are." {
                Section {
                    PAUSEStatusNotice(text: model.status)
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.large)
        .familyActivityPicker(isPresented: $choosingApps, selection: $model.selection)
        .onChange(of: model.selection) { _, _ in model.saveSelection() }
    }
}
