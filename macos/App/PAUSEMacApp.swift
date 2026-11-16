import SwiftUI

@main
struct PAUSEMacApp: App {
    @StateObject private var activity = MacActivityStore()
    @StateObject private var cloud = MacCloudSync()

    var body: some Scene {
        WindowGroup("PAUSE for Mac") {
            MacDashboard(activity: activity, cloud: cloud)
                .frame(minWidth: 680, minHeight: 610)
                .onAppear {
                    activity.startIfNeeded()
                    cloud.attach(activity: activity)
                }
        }
        .defaultSize(width: 840, height: 740)

        MenuBarExtra("PAUSE", systemImage: "circle.dotted.circle") {
            VStack(alignment: .leading, spacing: 12) {
                Text("PAUSE").font(.headline)
                Text(activity.isTracking ? "Recording active applications locally" : "Tracking paused")
                    .font(.caption)
                Text("Today: \(activity.totalMinutes) minutes of active time")
                Button(activity.isTracking ? "Pause monitoring" : "Resume monitoring") {
                    activity.isTracking.toggle()
                }
                Divider()
                Text("Browser integration: \(activity.bridgeStatus)")
                    .font(.caption)
                Text("Cloud: \(cloud.status)")
                    .font(.caption)
                Divider()
                Button("Quit PAUSE") { NSApplication.shared.terminate(nil) }
            }
            .padding(12)
            .frame(width: 270, alignment: .leading)
            .onAppear { activity.startIfNeeded() }
        }
    }
}
