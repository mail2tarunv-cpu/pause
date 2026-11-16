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

private enum PAUSEReportType {
    static func body(_ style: Font.TextStyle = .body, strong: Bool = false) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 36
        case .title2: size = 24
        case .headline: size = 17
        case .subheadline: size = 14
        case .caption: size = 11
        default: size = 15
        }
        return .custom(strong ? "DMMono-Medium" : "DMMono-Regular",
                       size: size, relativeTo: style)
    }
    static func heading(_ style: Font.TextStyle) -> Font {
        let size: CGFloat = style == .largeTitle ? 36 : 18
        return .custom("SpaceGrotesk-Bold", size: size, relativeTo: style)
    }
}

struct PAUSEDailyReportView: View {
    let configuration: PAUSEReportConfiguration
    private let accent = Color(red: 0.05, green: 0.53, blue: 0.46)

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Total today")
                        .font(PAUSEReportType.body(.subheadline))
                        .foregroundStyle(.secondary)
                    Text(duration(configuration.total))
                        .font(PAUSEReportType.heading(.largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(PAUSEReportType.heading(.title2))
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }

            if configuration.total == 0 {
                Label(
                    "No activity reported yet. Screen Time can take a few minutes to update.",
                    systemImage: "hourglass"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                if !configuration.categories.isEmpty {
                    Divider()
                    Text("Categories")
                        .font(PAUSEReportType.heading(.headline))
                    ForEach(configuration.categories) { entry in
                        usageRow(entry)
                    }
                }

                if !configuration.apps.isEmpty {
                    Divider()
                    Text("Most used apps")
                        .font(.headline)
                    ForEach(configuration.apps) { entry in
                        usageRow(entry)
                    }
                }
            }
            Label("Rendered privately by iOS", systemImage: "lock.shield")
                .font(PAUSEReportType.body(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func usageRow(_ entry: PAUSEReportConfiguration.Entry) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Text(entry.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(duration(entry.duration))
                    .font(PAUSEReportType.body(.subheadline, strong: true))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: entry.duration, total: max(configuration.total, 1))
                .tint(accent)
        }
        .accessibilityElement(children: .combine)
    }
}
