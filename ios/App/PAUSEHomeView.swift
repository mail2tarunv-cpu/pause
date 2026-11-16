import SwiftUI
import DeviceActivity
import FamilyControls

/// A native grouped overview. The Screen Time report remains inside Apple's
/// isolated extension; these view models never receive raw usage results.
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
                PAUSEIntro(
                    title: "Make room for what matters.",
                    subtitle: "A quieter way to notice how you use your time.",
                    symbol: "circle.dotted"
                )
            }
            .listRowBackground(Color.clear)

            Section("Screen Time") {
                if model.screenTimeAuthorized {
                    DeviceActivityReport(
                        DeviceActivityReport.Context("pause.daily"),
                        filter: DeviceActivityFilter(
                            segment: .daily(during: todayInterval),
                            devices: .init([.iPhone])
                        )
                    )
                    .frame(minHeight: 360, idealHeight: 520)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } else {
                    ContentUnavailableView {
                        Label("Screen Time is off", systemImage: "hourglass")
                    } description: {
                        Text("Allow access to view today's activity privately on this iPhone.")
                    } actions: {
                        Button("Allow Screen Time") {
                            Task { await model.authorizeScreenTime() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                }
            }

            Section("Your daily rule") {
                HStack(spacing: 12) {
                    Image(systemName: model.category.icon)
                        .font(.title3)
                        .foregroundStyle(PAUSEPalette.tint)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.category.title)
                            .font(.body.weight(.medium))
                        Text("\(model.selectionCount) selected apps, categories or sites")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(model.thresholdMinutes) min")
                            .font(.body.monospacedDigit().weight(.semibold))
                        Text(model.monitoring ? "Monitoring" : "Paused")
                            .font(.caption)
                            .foregroundStyle(model.monitoring ? .green : .secondary)
                    }
                }
                .padding(.vertical, 3)
            } footer: {
                Text("One cumulative daily threshold. It does not measure continuous sessions.")
            }

            Section("Recent check-ins") {
                if model.recentEvents.isEmpty {
                    PAUSEInfoRow(
                        symbol: "bell.slash",
                        title: "No check-ins yet",
                        explanation: "A reminder appears here when a selected daily threshold is reached."
                    )
                } else {
                    ForEach(model.recentEvents.prefix(5), id: \.id) { event in
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(event.category.capitalized) limit reached")
                                Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundStyle(PAUSEPalette.tint)
                        }
                    }
                }
            }

            if cloud.enabled && cloud.signedIn {
                Section("Mac activity · Synced") {
                    if cloud.macCategoryTotals.isEmpty {
                        PAUSEInfoRow(
                            symbol: "macbook",
                            title: "No Mac activity yet",
                            explanation: "Enable sharing in PAUSE for Mac to see category totals here."
                        )
                    } else {
                        ForEach(cloud.macCategoryTotals.keys.sorted(), id: \.self) { category in
                            HStack {
                                Text(category.capitalized)
                                Spacer()
                                Text("\((cloud.macCategoryTotals[category] ?? 0) / 60) min")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Only generic Mac categories sync. iPhone Screen Time remains private.")
                }
            }

            Section {
                PAUSEStatusNotice(text: model.status)
            }
            .listRowBackground(Color.clear)
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
