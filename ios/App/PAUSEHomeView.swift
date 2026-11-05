import SwiftUI
import DeviceActivity
import FamilyControls

struct PAUSEHomeView: View {
    @ObservedObject var model: PAUSEModel

    private var todayInterval: DateInterval {
        Calendar.current.dateInterval(of: .day, for: Date()) ??
            DateInterval(start: Date(), duration: 24 * 60 * 60)
    }

    var body: some View {
        PAUSEPage {
            PAUSEHeader(
                eyebrow: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
                headline: "More life.\nLess autopilot.",
                description: "Not all screen time is equal. PAUSE notices the moments you choose to pay attention to."
            )

            PAUSECard(color: PAUSEPalette.sage.opacity(0.55)) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "leaf")
                        .font(.system(size: 23))
                        .foregroundStyle(PAUSEPalette.ink)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your attention, your rules.")
                            .font(.system(size: 16, weight: .semibold))
                        Text("PAUSE doesn't block you or judge you. It gives you a moment to decide what happens next.")
                            .font(.system(size: 12))
                            .foregroundStyle(PAUSEPalette.ink.opacity(0.68))
                            .lineSpacing(3)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PAUSEKicker(text: "01  /  Today's activity")
                    Spacer()
                    PAUSEStatusPill(
                        text: model.screenTimeAuthorized ? "Private report" : "Not connected",
                        positive: model.screenTimeAuthorized
                    )
                }

                if model.screenTimeAuthorized {
                    DeviceActivityReport(
                        DeviceActivityReport.Context("pause.daily"),
                        filter: DeviceActivityFilter(
                            segment: .daily(during: todayInterval),
                            devices: .init([.iPhone])
                        )
                    )
                    .frame(minHeight: 360, idealHeight: 560, maxHeight: 640)
                } else {
                    PAUSECard {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 26))
                            .foregroundStyle(PAUSEPalette.secondary)
                        Text("Your Screen Time, privately.")
                            .font(.system(size: 21, weight: .medium, design: .rounded))
                        Text("Allow Screen Time access to view your real iPhone usage here. The report stays inside Apple's protected extension.")
                            .font(.system(size: 12))
                            .foregroundStyle(PAUSEPalette.secondary)
                            .lineSpacing(4)
                        Button("Connect Screen Time") {
                            Task { await model.authorizeScreenTime() }
                        }
                        .buttonStyle(PAUSEButton())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PAUSEKicker(text: "02  /  Your nudge rule")
                PAUSECard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(model.category.title)
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                            Text(model.category.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(PAUSEPalette.secondary)
                        }
                        Spacer()
                        PAUSEStatusPill(
                            text: model.monitoring ? "Monitoring" : "Paused",
                            positive: model.monitoring
                        )
                    }
                    Rectangle()
                        .fill(PAUSEPalette.line)
                        .frame(height: 1)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(model.thresholdMinutes)")
                            .font(.system(size: 42, weight: .medium, design: .rounded))
                        Text("minutes per day")
                            .font(.system(size: 12))
                            .foregroundStyle(PAUSEPalette.secondary)
                    }
                    Text("For \(model.selectionCount) selected apps, categories or websites. Cumulative daily use, not a continuous session.")
                        .font(.system(size: 11))
                        .foregroundStyle(PAUSEPalette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PAUSEKicker(text: "03  /  Recent check-ins")
                PAUSECard {
                    if model.recentEvents.isEmpty {
                        Text("No thresholds reached yet.")
                            .font(.system(size: 14, weight: .medium))
                        Text("Once iOS notifies PAUSE of a usage threshold, it'll appear here. This is not your complete usage history.")
                            .font(.system(size: 12))
                            .foregroundStyle(PAUSEPalette.secondary)
                            .lineSpacing(3)
                    } else {
                        ForEach(model.recentEvents.prefix(3), id: \.id) { event in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "clock")
                                    .foregroundStyle(PAUSEPalette.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(event.category.capitalized) threshold reached")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11))
                                        .foregroundStyle(PAUSEPalette.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            PAUSEStatusNotice(text: model.status)
        }
    }
}
