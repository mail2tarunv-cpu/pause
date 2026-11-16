import SwiftUI
import FamilyControls

/// Rules use the same grouped forms and pickers people know from iOS Settings.
struct PAUSERulesView: View {
    @ObservedObject var model: PAUSEModel
    @State private var choosingApps = false

    var body: some View {
        Form {
            Section {
                PAUSEIntro(
                    title: "A nudge, not a wall.",
                    subtitle: "Choose what PAUSE watches and when it should check in.",
                    symbol: "leaf"
                )
            }
            .listRowBackground(Color.clear)

            Section {
                HStack {
                    Label("Screen Time", systemImage: "hourglass")
                    Spacer()
                    Text(model.screenTimeAuthorized ? "Allowed" : "Required")
                        .foregroundStyle(model.screenTimeAuthorized ? Color.green : Color.secondary)
                }
                if !model.screenTimeAuthorized {
                    Button("Allow Screen Time access") {
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
            } header: {
                Text("Permissions")
            } footer: {
                Text("Apple controls the app-selection picker and private Screen Time reports.")
            }

            Section {
                Button {
                    choosingApps = true
                } label: {
                    HStack(spacing: 10) {
                        Label("Choose apps and sites", systemImage: "square.grid.2x2")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(PAUSEType.body(.caption))
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(!model.screenTimeAuthorized)

                LabeledContent("Selected activity", value: "\(model.selectionCount) items")
            } header: {
                Text("Activity")
            } footer: {
                Text("Only selected apps, categories and websites contribute to the daily threshold.")
            }

            Section {
                Stepper(
                    value: $model.thresholdMinutes,
                    in: 5...240,
                    step: 5
                ) {
                    LabeledContent("Daily limit") {
                        Text("\(model.thresholdMinutes) min")
                            .monospacedDigit()
                            .fontWeight(.semibold)
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
                Text("This is cumulative time per day, not one uninterrupted session. Reminder style changes the wording, not which apps are monitored.")
            }

            Section("Preview") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.category.title + " reminder")
                            .font(PAUSEType.body(.body, strong: true))
                        Text(model.category.detail)
                            .font(PAUSEType.body(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: model.category.icon)
                        .foregroundStyle(PAUSEPalette.tint)
                }
            }

            Section {
                Button {
                    model.startMonitoring()
                } label: {
                    HStack {
                        Spacer()
                        Label(model.monitoring ? "Update monitoring" : "Start monitoring",
                              systemImage: model.monitoring ? "checkmark.circle" : "play.fill")
                        Spacer()
                    }
                }
                .fontWeight(.semibold)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!model.screenTimeAuthorized || !model.hasSelection)

                if model.monitoring {
                    Button(role: .destructive) {
                        model.stopMonitoring()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Stop monitoring", systemImage: "pause.fill")
                            Spacer()
                        }
                    }
                }
            } footer: {
                Text(model.monitoring ? "Monitoring is enabled." : "Monitoring is currently paused.")
            }

            Section {
                PAUSEStatusNotice(text: model.status)
            }.listRowBackground(Color.clear)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(PAUSEPalette.background)
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $choosingApps, selection: $model.selection)
        .onChange(of: model.selection) { _, _ in model.saveSelection() }
    }
}
