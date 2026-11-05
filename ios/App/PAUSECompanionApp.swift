import SwiftUI
import UserNotifications
import UIKit

// PAUSE for iPhone is independent of the Mac and of ActivityWatch.
// Screen Time totals are rendered privately by Apple's report extension.
@main
struct PAUSECompanionApp: App {
    @UIApplicationDelegateAdaptor(PAUSEAppDelegate.self) private var appDelegate
    @StateObject private var model = PAUSEModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PAUSERootView(model: model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.reloadFromExtension()
                    }
                }
        }
    }
}

final class PAUSEAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

struct PAUSERootView: View {
    @ObservedObject var model: PAUSEModel

    var body: some View {
        TabView {
            PAUSEHomeView(model: model)
                .tabItem { Label("Today", systemImage: "square.grid.2x2") }

            PAUSERulesView(model: model)
                .tabItem { Label("Rules", systemImage: "slider.horizontal.3") }

            PAUSEBoardView(model: model)
                .tabItem { Label("Board", systemImage: "rectangle.on.rectangle") }

            PAUSESettingsView(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(PAUSEPalette.ink)
    }
}
