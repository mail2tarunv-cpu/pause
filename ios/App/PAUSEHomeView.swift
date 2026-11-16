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

            Section {
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
            } header: {
                PAUSESectionHeading(title: "Screen Time")
            }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: model.category.icon)
                        .font(PAUSEType.heading(.title3))
                        .foregroundStyle(model.category.accent)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.category.title)
                            .font(PAUSEType.body(.body, strong: true))
                        Text("\(model.selectionCount) selected apps, categories or sites")
                            .font(PAUSEType.body(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(model.thresholdMinutes) min")
                            .font(PAUSEType.body(.body, strong: true))
                        Text(model.monitoring ? "Monitoring" : "Paused")
                            .font(PAUSEType.body(.caption))
                            .foregroundStyle(model.monitoring ? .green : .secondary)
                    }
                }
                .padding(.vertical, 3)
            } header: {
                Text("Your daily rule")
            } footer: {
                Text("One cumulative daily threshold. It does not measure continuous sessions.")
            }

            Section {
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
                                    .font(PAUSEType.body(.caption))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundStyle(PAUSEPalette.tint)
                        }
                    }
                }
            } header: {
                PAUSESectionHeading(title: "Recent check-ins")
            }

            if cloud.enabled && cloud.signedIn {
                Section {
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
                } header: {
                    Text("Mac activity · Synced")
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
        .scrollContentBackground(.hidden)
        .background(PAUSEPalette.background)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text(Date().formatted(.dateTime.month(.abbreviated).day()))
                    .font(PAUSEType.body(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            if cloud.enabled { await cloud.syncLocalEvents() }
        }
    }
}
