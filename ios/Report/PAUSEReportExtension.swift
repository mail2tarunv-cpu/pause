import SwiftUI
import DeviceActivity
import FamilyControls

// The Screen Time data lives and stays inside this Apple-protected extension.
// The host app displays this SwiftUI view, but never receives the raw results.
@main
struct PAUSEReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        PAUSEDailyScene { configuration in
            PAUSEDailyReportView(configuration: configuration)
        }
    }
}

struct PAUSEReportConfiguration {
    struct Entry: Identifiable {
        let id: String
        let title: String
        let duration: TimeInterval
    }

    let total: TimeInterval
    let categories: [Entry]
    let apps: [Entry]
}

struct PAUSEDailyScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("pause.daily")
    let content: (PAUSEReportConfiguration) -> PAUSEDailyReportView

    func makeConfiguration(
        representing results: DeviceActivityResults<DeviceActivityData>
    ) async -> PAUSEReportConfiguration {
        var total: TimeInterval = 0
        var categoryDurations: [String: TimeInterval] = [:]
        var appDurations: [String: TimeInterval] = [:]

        for await activity in results {
            for await segment in activity.activitySegments {
                total += segment.totalActivityDuration

                for await category in segment.categories {
                    let title = category.category.localizedDisplayName ?? "Other"
                    categoryDurations[title, default: 0] += category.totalActivityDuration

                    for await app in category.applications {
                        let title = app.application.localizedDisplayName ?? "Private app"
                        appDurations[title, default: 0] += app.totalActivityDuration
                    }
                }
            }
        }

        func entries(_ values: [String: TimeInterval]) -> [PAUSEReportConfiguration.Entry] {
            values
                .filter { $0.value > 0 }
                .map { PAUSEReportConfiguration.Entry(id: $0.key, title: $0.key, duration: $0.value) }
                .sorted { $0.duration > $1.duration }
        }

        return .init(
            total: total,
            categories: Array(entries(categoryDurations).prefix(4)),
            apps: Array(entries(appDurations).prefix(5))
        )
    }
}

struct PAUSEDailyReportView: View {
    let configuration: PAUSEReportConfiguration
    private let ink = Color(red: 0.13, green: 0.14, blue: 0.13)
    private let warm = Color(red: 0.94, green: 0.92, blue: 0.87)

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SCREEN TIME TODAY")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.8).foregroundStyle(ink.opacity(0.58))
                    Text(duration(configuration.total))
                        .font(.system(size: 40, weight: .medium, design: .rounded))
                        .tracking(-1.4).foregroundStyle(ink)
                }
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(ink.opacity(0.4))
            }

            if configuration.total == 0 {
                Text("No activity has been reported for today yet. Screen Time may need a few minutes to update.")
                    .font(.system(size: 13)).foregroundStyle(ink.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if !configuration.categories.isEmpty {
                    Text("BY CATEGORY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4).foregroundStyle(ink.opacity(0.55))
                    ForEach(configuration.categories) { entry in
                        usageRow(entry)
                    }
                }

                if !configuration.apps.isEmpty {
                    Divider().overlay(ink.opacity(0.1))
                    Text("MOST USED APPS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4).foregroundStyle(ink.opacity(0.55))
                    ForEach(configuration.apps) { entry in
                        usageRow(entry)
                    }
                }
            }
            Text("Rendered privately by iOS. PAUSE cannot upload the underlying usage report.")
                .font(.system(size: 10))
                .foregroundStyle(ink.opacity(0.48))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(warm, in: RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder private func usageRow(_ entry: PAUSEReportConfiguration.Entry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(duration(entry.duration))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ink.opacity(0.08))
                    Capsule()
                        .fill(ink.opacity(0.7))
                        .frame(width: max(3, proxy.size.width * min(1, entry.duration / max(configuration.total, 1))))
                }
            }
            .frame(height: 5)
        }
        .foregroundStyle(ink)
    }
}
