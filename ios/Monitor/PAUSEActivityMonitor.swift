import DeviceActivity
import Foundation
import UserNotifications

/// Apple launches this extension when the selected activity reaches its
/// cumulative daily threshold. No app identities or raw history leave iOS.
final class PAUSEActivityMonitor: DeviceActivityMonitor {
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity == DeviceActivityName("pause.selected.daily"),
              event == DeviceActivityEvent.Name("pause.selected.limit") else {
            return
        }

        let allowed = ["social", "creative", "entertainment"]
        let selected = PAUSETransport.preferences?
            .string(forKey: "selectedCategory") ?? "social"
        let category = allowed.contains(selected) ? selected : "social"

        // Stores one local threshold event; stages a remote event ONLY if
        // the user explicitly enabled forwarding on the Board screen.
        PAUSETransport.stageThreshold(category: category)

        let message: String
        switch category {
        case "creative":
            message = "A good moment to stretch or rest. You choose."
        case "entertainment":
            message = "Ready for a check-in, or want to keep watching?"
        default:
            message = "You reached the limit you set. Want to step away?"
        }

        // Works without a Mac, relay, browser extension, or cloud account.
        // iOS will present this only when notifications are authorized.
        let notice = UNMutableNotificationContent()
        notice.title = "A little PAUSE"
        notice.body = message
        notice.sound = .default
        notice.categoryIdentifier = "PAUSE_THRESHOLD"
        let request = UNNotificationRequest(
            identifier: "pause-threshold-\(UUID().uuidString)",
            content: notice,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("PAUSE could not schedule its notification: %@", String(describing: error))
            }
        }

        // Best-effort LAN delivery only. Apple may suspend extensions before
        // network completion; a recent pending event retries on app opening.
        if PAUSETransport.preferences?.bool(forKey: PAUSETransport.forwardKey) == true {
            Task { try? await PAUSETransport.flushPending() }
        }
    }
}
