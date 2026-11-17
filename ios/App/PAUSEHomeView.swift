import SwiftUI
import DeviceActivity
import FamilyControls

/// Native iOS overview. Apple's protected report view owns the usage data.
struct PAUSEHomeView: View {
    @ObservedObject var model: PAUSEModel
    @ObservedObject private var cloud = PAUSECloud.shared

    private var todayInterval: DateInterval {
        Calendar.current.dateInterval(of: .day, for: Date()) ??
            DateInterval(start: Date(), duration: 86400)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: model.monitoring ? "checkmark.circle.fill" : "pause.circle")
                        .font(.title2)
                        .foregroundStyle(model.monitoring ? Color.green : Color.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.monitoring ? "Monitoring is on" : "Monitoring is paused")
                            .font(.headline)
                        Text(model.monitoring
                             ? "PAUSE will check in when your daily limit is reached."
                             : "Set a daily rule to receive a reminder.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }

            Section {
                if model.screenTimeAuthorized {
                    DeviceActivityReport(
                        DeviceActivityReport.Context("pause.daily"),
                        filter: DeviceActivityFilter(
                            segment: .daily(during: todayInterval),
                            devices: .init([.iPhone])
                        )
                    )
                    .frame(minHeight: 340, idealHeight: 440)
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                } else {
                    ContentUnavailableView {
                        Label("Screen Time is off", systemImage: "hourglass")
                    } description: {
                        Text("Allow Screen Time access to view today's activity.")
                    } actions: {
                        Button("Allow Screen Time") {
                            Task { await model.authorizeScreenTime() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Screen Time")
            } footer: {
                Text("This report is generated privately by iOS. PAUSE does not read the underlying app history.")
            }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: model.category.icon)
                        .font(.title3)
                        .frame(width: 30)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.category.title + " reminder")
                            .font(.body.weight(.medium))
                        Text("\(model.selectionCount) selected items")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(model.thresholdMinutes) min")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                        Text("Per day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Daily rule")
            } footer: {
                Text("The limit is cumulative over the day, not one continuous session.")
            }

            Section {
                if model.recentEvents.isEmpty {
                    PAUSEInfoRow(symbol: "bell.slash",
                                 title: "No reminders yet",
                                 explanation: "Check-ins appear here after you reach your selected limit.")
                } else {
                    ForEach(model.recentEvents.prefix(5), id: \.id) { event in
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.category.capitalized + " limit reached")
                                    .font(.body.weight(.medium))
                                Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "bell")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Recent check-ins")
            }

            if cloud.enabled && cloud.signedIn {
                Section {
                    if cloud.macCategoryTotals.isEmpty {
                        PAUSEInfoRow(symbol: "macbook",
                                     title: "No synced Mac activity",
                                     explanation: "Enable sharing in PAUSE for Mac to see category totals.")
                    } else {
                        ForEach(cloud.macCategoryTotals.keys.sorted(), id: \.self) { category in
                            LabeledContent(category.capitalized,
                                           value: "\((cloud.macCategoryTotals[category] ?? 0) / 60) min")
                        }
                    }
                } header: {
                    Text("Mac activity")
                } footer: {
                    Text("Only category totals are synced. Your iPhone Screen Time stays private.")
                }
            }

            if model.status != "Ready when you are." {
                Section {
                    PAUSEStatusNotice(text: model.status)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text(Date().formatted(.dateTime.month(.abbreviated).day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            if cloud.enabled { await cloud.syncLocalEvents() }
        }
    }
}
