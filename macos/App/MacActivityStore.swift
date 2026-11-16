import AppKit
import Combine
import CoreGraphics
import Foundation

/// Captures only foreground application identity, duration and (optionally)
/// the active website's domain sent by an explicitly installed browser extension.
/// No window titles, screenshots, keystrokes, URLs or page contents are read.
struct ActivityRecord: Codable, Identifiable {
    let id: String
    let day: String
    let label: String
    let category: String
    let kind: String
    var seconds: Int
}

@MainActor
final class MacActivityStore: ObservableObject {
    @Published var records: [ActivityRecord] = []
    @Published var isTracking = true
    @Published var foreground = "Waiting for activity"
    @Published var bridgeStatus = "Starting"
    @Published var browserPairingCode = ""
    @Published var lastWebsite = "No site observed"
    @Published var cloudBoardMessage: String? = nil

    private var started = false
    private var lastTick = Date()
    private var tickTimer: Timer?
    private var lastSave = Date()
    private var browserDomain: String?
    private var browserSeenAt: Date?
    private var websiteBridge: WebsiteBridge?

    var totalMinutes: Int {
        todayRecords.reduce(0) { $0 + $1.seconds } / 60
    }
    var todayRecords: [ActivityRecord] {
        records.filter { $0.day == Self.today() }.sorted { $0.seconds > $1.seconds }
    }
    var byCategory: [(String, Int)] {
        let totals = Dictionary(grouping: todayRecords, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.seconds } }
        return totals.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }
    var isWebsiteConnected: Bool {
        guard let browserSeenAt else { return false }
        return Date().timeIntervalSince(browserSeenAt) < 75
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "pause-mac-local-records"),
           let saved = try? JSONDecoder().decode([ActivityRecord].self, from: data) {
            let cutoff = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? .distantPast
            let cutoffDay = Self.dayString(cutoff)
            records = saved.filter { $0.day >= cutoffDay }
        }
        browserPairingCode = UserDefaults.standard.string(forKey: "pause-browser-token") ?? ""
        if browserPairingCode.isEmpty {
            resetBrowserToken()
        }
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func today() -> String { dayString(Date()) }

    func resetBrowserToken() {
        let bytes = (0..<24).map { _ in UInt8.random(in: 0...255) }
        browserPairingCode = bytes.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(browserPairingCode, forKey: "pause-browser-token")
        browserDomain = nil
        browserSeenAt = nil
    }

    func startIfNeeded() {
        guard !started else { return }
        started = true
        lastTick = Date()
        websiteBridge = WebsiteBridge { [weak self] domain in
            Task { @MainActor in self?.receiveActiveDomain(domain) }
        }
        do {
            try websiteBridge?.start(token: { [weak self] in
                // Token is read on main when bridge is initialized; refresh via
                // UserDefaults for safe background verification.
                UserDefaults.standard.string(forKey: "pause-browser-token") ?? ""
            })
            bridgeStatus = "Listening on 127.0.0.1:8766"
        } catch {
            bridgeStatus = "Port 8766 unavailable"
        }

        tickTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        tickTimer?.tolerance = 1.0
        // Initial display status, without inventing usage.
        sample()
    }

    func receiveActiveDomain(_ domain: String?) {
        guard let domain, !domain.isEmpty else {
            browserDomain = nil
            browserSeenAt = nil
            lastWebsite = "No site observed"
            return
        }
        browserDomain = domain
        browserSeenAt = Date()
        lastWebsite = domain
    }

    private func sample() {
        let now = Date()
        let delta = min(6.0, max(0, now.timeIntervalSince(lastTick)))
        lastTick = now

        guard isTracking else {
            foreground = "Monitoring paused"
            return
        }

        // Protect against counting time spent asleep or away from the keyboard.
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .null
        )
        guard idle.isFinite, idle < 60 else {
            foreground = "Idle — not counted"
            return
        }
        guard let app = NSWorkspace.shared.frontmostApplication,
              let name = app.localizedName, !name.isEmpty,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            foreground = "No foreground application"
            return
        }

        let bundle = app.bundleIdentifier ?? name
        let isBrowser = Self.isBrowser(bundle, name)
        let latestSite = browserSeenAt != nil &&
                         now.timeIntervalSince(browserSeenAt!) <= 40 ?
                         browserDomain : nil
        let site = isBrowser ? latestSite : nil
        let label = site ?? name
        let kind = site == nil ? "app" : "site"
        let category = Self.category(for: site ?? bundle, name: name)
        foreground = site == nil ? name : "\(name) · \(site!)"

        // 5s sampling naturally accommodates notifications, sleep and idle.
        let seconds = Int(delta.rounded())
        guard seconds > 0 else { return }
        let day = Self.today()
        let identity = "\(day)|\(kind)|\(label.lowercased())"
        if let index = records.firstIndex(where: { $0.id == identity }) {
            records[index].seconds += seconds
        } else {
            records.append(ActivityRecord(
                id: identity, day: day, label: label,
                category: category, kind: kind, seconds: seconds
            ))
        }
        // Avoid writing a file five times each minute.
        if now.timeIntervalSince(lastSave) >= 30 {
            persist()
            lastSave = now
        }
    }

    func persist() {
        let cutoff = Self.dayString(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
        records.removeAll { $0.day < cutoff }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "pause-mac-local-records")
        }
    }

    func clearRecords() {
        records.removeAll()
        UserDefaults.standard.removeObject(forKey: "pause-mac-local-records")
    }

    static func isBrowser(_ bundle: String, _ name: String) -> Bool {
        let text = (bundle + " " + name).lowercased()
        return ["chrome", "chromium", "brave", "arc", "edge", "firefox", "safari", "vivaldi", "opera"]
            .contains { text.contains($0) }
    }

    static func category(for identifier: String, name: String) -> String {
        let text = (identifier + " " + name).lowercased()
        if ["instagram", "tiktok", "facebook", "reddit", "twitter", "threads.net", "discord",
            "snapchat", "pinterest", "x.com", "telegram"].contains(where: text.contains) {
            return "social"
        }
        if ["figma", "sketch", "photoshop", "illustrator", "blender", "xcode",
            "cursor", "code", "notion", "github", "linear", "canva", "terminal"].contains(where: text.contains) {
            return "creative"
        }
        if ["youtube", "netflix", "twitch", "hulu", "spotify", "steam", "primevideo",
            "disneyplus", "vlc"].contains(where: text.contains) {
            return "entertainment"
        }
        return "other"
    }
}
