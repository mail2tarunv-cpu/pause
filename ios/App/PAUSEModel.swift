import Foundation
import Combine
import FamilyControls
import DeviceActivity
import UserNotifications

enum PAUSECategory: String, CaseIterable, Identifiable {
    case social, creative, entertainment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .social: return "Social"
        case .creative: return "Creative"
        case .entertainment: return "Entertainment"
        }
    }

    var message: String {
        switch self {
        case .social: return "YOU REACHED YOUR LIMIT\n\nREADY TO STEP AWAY?"
        case .creative: return "YOU HAVE BEEN CREATING\nFOR A WHILE\n\nSTRETCH BREAK?"
        case .entertainment: return "TIME FOR A CHECK-IN\n\nKEEP WATCHING OR PAUSE?"
        }
    }

    var detail: String {
        switch self {
        case .social: return "A direct check-in to interrupt endless scrolling"
        case .creative: return "A gentle stretch or rest reminder"
        case .entertainment: return "An invitation to choose whether to continue"
        }
    }

    var icon: String {
        switch self {
        case .social: return "bubble.left.and.bubble.right"
        case .creative: return "paintbrush.pointed"
        case .entertainment: return "play.rectangle"
        }
    }
}

@MainActor
final class PAUSEModel: ObservableObject {
    private let activityName = DeviceActivityName("pause.selected.daily")
    private let eventName = DeviceActivityEvent.Name("pause.selected.limit")

    @Published var selection = FamilyActivitySelection()
    @Published var category: PAUSECategory = .social
    @Published var thresholdMinutes: Int = 20
    @Published var monitoring = false
    @Published var screenTimeAuthorized = false
    @Published var notificationAuthorized = false
    @Published var isWorking = false
    @Published var status = "Ready when you are."
    @Published var recentEvents: [PAUSETransport.PendingThreshold] = []
    @Published var boardAddress = ""
    @Published var boardKey = ""
    @Published var boardConnected = false
    @Published var boardDraft = "TAKE A LITTLE PAUSE\nYOU ARE ALLOWED TO\nDO NOTHING AT ALL"

    var selectionCount: Int {
        selection.applicationTokens.count +
        selection.categoryTokens.count +
        selection.webDomainTokens.count
    }

    var hasSelection: Bool { selectionCount > 0 }

    init() {
        load()
    }

    func load() {
        let store = PAUSETransport.preferences
        if let data = store?.data(forKey: "selection"),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        }
        if let name = store?.string(forKey: "selectedCategory"),
           let value = PAUSECategory(rawValue: name) {
            category = value
        }
        let savedMinutes = store?.integer(forKey: "selectedMinutes") ?? 0
        thresholdMinutes = savedMinutes >= 5 ? savedMinutes : 20
        boardAddress = store?.string(forKey: PAUSETransport.bridgeKey) ?? ""
        boardKey = store?.string(forKey: PAUSETransport.pairingKey) ?? ""
        boardDraft = store?.string(forKey: "boardDraft") ??
            "TAKE A LITTLE PAUSE\nYOU ARE ALLOWED TO\nDO NOTHING AT ALL"
        screenTimeAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        monitoring = DeviceActivityCenter().activities.contains(activityName)
        recentEvents = PAUSETransport.history()
        Task { await refreshNotifications() }
    }

    func reloadFromExtension() {
        recentEvents = PAUSETransport.history()
        monitoring = DeviceActivityCenter().activities.contains(activityName)
        screenTimeAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        Task {
            // Do not require the optional Mac to use the iPhone app.
            try? await PAUSETransport.flushPending()
        }
    }

    func saveSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            PAUSETransport.preferences?.set(data, forKey: "selection")
        }
    }

    func authorizeScreenTime() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            screenTimeAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
            status = screenTimeAuthorized ?
                "Screen Time access granted. Choose what to monitor." :
                "Screen Time access wasn't approved."
        } catch {
            screenTimeAuthorized = false
            status = "Screen Time permission: \(error.localizedDescription)"
        }
    }

    func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            notificationAuthorized = granted
            status = granted ? "Notifications enabled." : "Notifications are disabled. Monitoring still works."
        } catch {
            status = "Notification permission: \(error.localizedDescription)"
        }
    }

    func refreshNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthorized = settings.authorizationStatus == .authorized ||
                                 settings.authorizationStatus == .provisional
    }

    func startMonitoring() {
        guard screenTimeAuthorized else {
            status = "Allow Screen Time access before starting."
            return
        }
        guard hasSelection else {
            status = "Choose at least one app, category or website."
            return
        }

        saveSelection()
        PAUSETransport.preferences?.set(category.rawValue, forKey: "selectedCategory")
        PAUSETransport.preferences?.set(thresholdMinutes, forKey: "selectedMinutes")

        // One cumulative usage threshold per day, across the chosen selection.
        // This does NOT measure an uninterrupted session.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: thresholdMinutes)
        )
        do {
            DeviceActivityCenter().stopMonitoring([activityName])
            try DeviceActivityCenter().startMonitoring(
                activityName, during: schedule, events: [eventName: event]
            )
            monitoring = true
            status = "Monitoring started. PAUSE will check your selected activity each day."
        } catch {
            monitoring = false
            status = "Could not start monitoring: \(error.localizedDescription)"
        }
    }

    func stopMonitoring() {
        DeviceActivityCenter().stopMonitoring([activityName])
        monitoring = false
        status = "Monitoring paused. No thresholds will be checked."
    }

    func clearLocalHistory() {
        PAUSETransport.clearHistory()
        recentEvents = []
        status = "Local threshold history cleared."
    }

    func saveBoardConnection() {
        PAUSETransport.configure(address: boardAddress, code: boardKey)
    }

    func pairBoard() async {
        saveBoardConnection()
        isWorking = true
        defer { isWorking = false }
        do {
            try await PAUSETransport.send(action: "ping")
            boardConnected = true
            status = "Connected to your PAUSE board."
            try? await PAUSETransport.flushPending()
        } catch {
            boardConnected = false
            status = "Board connection failed: \(error.localizedDescription)"
        }
    }

    func sendCustomMessage() async {
        saveBoardConnection()
        isWorking = true
        defer { isWorking = false }
        let message = boardDraft.uppercased()
        PAUSETransport.preferences?.set(message, forKey: "boardDraft")
        do {
            try await PAUSETransport.send(action: "message", message: message)
            boardConnected = true
            status = "Message delivered to the PAUSE board."
        } catch {
            boardConnected = false
            status = "Message not delivered: \(error.localizedDescription)"
        }
    }

    func sendExampleNudge() async {
        saveBoardConnection()
        isWorking = true
        defer { isWorking = false }
        do {
            try await PAUSETransport.send(action: "threshold", category: category.rawValue)
            boardConnected = true
            status = "Example \(category.title.lowercased()) nudge sent to the board."
        } catch {
            boardConnected = false
            status = "Could not send: \(error.localizedDescription)"
        }
    }

    func clearBoard() async {
        saveBoardConnection()
        isWorking = true
        defer { isWorking = false }
        do {
            try await PAUSETransport.send(action: "clear")
            boardConnected = true
            status = "Board message cleared."
        } catch {
            status = "Could not clear the board: \(error.localizedDescription)"
        }
    }
}
