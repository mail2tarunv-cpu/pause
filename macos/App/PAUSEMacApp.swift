import SwiftUI
import AppKit

@main
struct PAUSEMacApp: App {
    @StateObject private var activity = MacActivityStore()
    @StateObject private var cloud = MacCloudSync()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("PAUSE for Mac", id: "main") {
            MacDashboard(activity: activity, cloud: cloud)
                .frame(minWidth: 740, minHeight: 560)
                .onAppear {
                    activity.startIfNeeded()
                    cloud.attach(activity: activity)
                }
        }
        .defaultSize(width: 970, height: 750)

        MenuBarExtra("PAUSE", systemImage: "circle.dotted") {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open PAUSE", systemImage: "macwindow")
            }
            Divider()
            Text("Today: \(activity.totalMinutes) minutes")
            Text(activity.isTracking ? "Tracking locally" : "Monitoring paused")
            Button {
                activity.isTracking.toggle()
                activity.persist()
            } label: {
                Label(activity.isTracking ? "Pause Monitoring" : "Resume Monitoring",
                      systemImage: activity.isTracking ? "pause" : "play")
            }
            Divider()
            Text(activity.isWebsiteConnected ? "Browser connected" : "Browser not connected")
            Text(cloud.authenticated ? "Cloud signed in" : "Cloud not connected")
            Divider()
            Button("Quit PAUSE") { NSApp.terminate(nil) }
        }
    }
}
