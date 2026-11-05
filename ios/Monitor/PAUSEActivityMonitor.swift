import DeviceActivity
import Foundation

/// Runs in an Apple-managed Screen Time extension, not in the main app.
/// A threshold is first queued in shared App Group storage. A best-effort
/// send is attempted, but iOS may suspend the extension before it finishes.
/// The foreground PAUSE app retries queued events on its next launch.
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
        let savedCategory = PAUSETransport.preferences?
            .string(forKey: "selectedCategory") ?? "social"
        let category = allowed.contains(savedCategory) ? savedCategory : "social"

        // App tokens, browsing history, app titles, and private usage details
        // are never sent out of the extension.
        PAUSETransport.stageThreshold(category: category)
        Task {
            try? await PAUSETransport.flushPending()
        }
    }
}
