import Foundation
import Combine
import Security

/// Optional cloud account for the iPhone. Apple Screen Time stays inside the
/// protected report extension. Only generic check-in events are synchronized.
@MainActor
final class PAUSECloud: ObservableObject {
    static let shared = PAUSECloud()

    @Published var projectURL = UserDefaults.standard.string(forKey: "pause-ios-cloud-url") ?? ""
    @Published var publishableKey = UserDefaults.standard.string(forKey: "pause-ios-cloud-key") ?? ""
    @Published var email = ""
    @Published var password = ""
    @Published var enabled = UserDefaults.standard.bool(forKey: "pause-ios-cloud-enabled")
    @Published var signedIn = false
    @Published var status = "Cloud is optional. Everything else stays local."
    @Published var macCategoryTotals: [String: Int] = [:]

    private var access = PAUSEKeychain.load("access") ?? ""
    private var refresh = PAUSEKeychain.load("refresh") ?? ""
    private var expires = UserDefaults.standard.double(forKey: "pause-ios-cloud-expires")
    private var owner = UserDefaults.standard.string(forKey: "pause-ios-cloud-owner") ?? ""

    private let deviceID: String = {
        if let existing = UserDefaults.standard.string(forKey: "pause-ios-cloud-device") {
            return existing
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: "pause-ios-cloud-device")
        return value
    }()

    private init() { signedIn = !access.isEmpty && !owner.isEmpty }

    private var baseURL: String? {
        let value = projectURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: value), url.scheme == "https",
              let hostname = url.host,
              hostname.hasSuffix(".supabase.co") || hostname.hasSuffix(".supabase.in"),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty else { return nil }
        return value
    }

    private func request(
        _ path: String,
        method: String = "GET",
        payload: Any? = nil,
        authorized: Bool = true,
        prefer: String? = nil
    ) async throws -> Any {
        guard let baseURL, (publishableKey.hasPrefix("sb_publishable_") || publishableKey.hasPrefix("eyJ")) else {
            throw CloudError.message("Enter your project URL and public key.")
        }
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if authorized {
            try await refreshIfNeeded()
            request.setValue("Bearer " + access, forHTTPHeaderField: "Authorization")
        }
        if let payload { request.httpBody = try JSONSerialization.data(withJSONObject: payload) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudError.message("No response from the server.")
        }
        guard (200...299).contains(http.statusCode) else {
            throw CloudError.message("Cloud returned HTTP \(http.statusCode).")
        }
        return data.isEmpty ? [:] : try JSONSerialization.jsonObject(with: data)
    }

    private func refreshIfNeeded() async throws {
        guard !access.isEmpty else { throw CloudError.message("Sign in to PAUSE first.") }
        if Date().timeIntervalSince1970 < expires - 90 { return }
        guard !refresh.isEmpty else { throw CloudError.message("Session expired. Sign in again.") }
        let result = try await request(
            "/auth/v1/token?grant_type=refresh_token", method: "POST",
            payload: ["refresh_token": refresh], authorized: false
        )
        try saveSession(result)
    }

    private func saveSession(_ result: Any) throws {
        guard let session = result as? [String: Any],
              let token = session["access_token"] as? String,
              let refreshToken = session["refresh_token"] as? String,
              let seconds = session["expires_in"] as? Int,
              let user = session["user"] as? [String: Any],
              let uid = user["id"] as? String else {
            throw CloudError.message("No active session. Check whether your email needs confirmation.")
        }
        access = token
        refresh = refreshToken
        owner = uid
        expires = Date().timeIntervalSince1970 + Double(seconds)
        PAUSEKeychain.save(token, key: "access")
        PAUSEKeychain.save(refreshToken, key: "refresh")
        UserDefaults.standard.set(uid, forKey: "pause-ios-cloud-owner")
        UserDefaults.standard.set(expires, forKey: "pause-ios-cloud-expires")
        password = ""
        signedIn = true
    }

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            status = "Enter your email and password."
            return
        }
        UserDefaults.standard.set(projectURL, forKey: "pause-ios-cloud-url")
        UserDefaults.standard.set(publishableKey, forKey: "pause-ios-cloud-key")
        status = "Signing in…"
        do {
            let session = try await request(
                "/auth/v1/token?grant_type=password", method: "POST",
                payload: ["email": email, "password": password], authorized: false
            )
            try saveSession(session)
            status = "Signed in. Enable cloud sync when you're ready."
            if enabled { await syncLocalEvents() }
        } catch {
            status = error.localizedDescription
        }
    }

    func signOut() {
        PAUSEKeychain.delete("access")
        PAUSEKeychain.delete("refresh")
        access = ""
        refresh = ""
        owner = ""
        expires = 0
        signedIn = false
        setEnabled(false)
        UserDefaults.standard.removeObject(forKey: "pause-ios-cloud-owner")
        UserDefaults.standard.removeObject(forKey: "pause-ios-cloud-expires")
        macCategoryTotals = [:]
        status = "Signed out. Local PAUSE data remains on the device."
    }

    func setEnabled(_ on: Bool) {
        enabled = on && signedIn
        UserDefaults.standard.set(enabled, forKey: "pause-ios-cloud-enabled")
        status = enabled ?
            "Sharing generic threshold events only. Raw usage stays on iPhone." :
            "Cross-device sync is disabled."
        if enabled { Task { await syncLocalEvents() } }
    }

    private func registerDevice() async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        _ = try await request(
            "/rest/v1/pause_devices?on_conflict=user_id,id",
            method: "POST",
            payload: [[
                "user_id": owner,
                "id": deviceID,
                "kind": "iphone",
                "label": "PAUSE for iPhone",
                "last_seen": timestamp
            ]],
            prefer: "resolution=merge-duplicates,return=minimal"
        )
    }

    func syncLocalEvents() async {
        guard signedIn, enabled else { return }
        do {
            try await registerDevice()
            let events = PAUSETransport.history().filter {
                Date().timeIntervalSince($0.occurredAt) <= 7 * 24 * 60 * 60
            }
            if !events.isEmpty {
                let iso = ISO8601DateFormatter()
                let payload: [[String: String]] = events.map {
                    ["id": $0.id.lowercased(),
                     "user_id": owner,
                     "device_id": deviceID,
                     "category": $0.category,
                     "occurred_at": iso.string(from: $0.occurredAt),
                     "delivery": "recorded"]
                }
                _ = try await request(
                    "/rest/v1/pause_nudge_events?on_conflict=id",
                    method: "POST", payload: payload,
                    prefer: "resolution=ignore-duplicates,return=minimal"
                )
            }
            await loadMacSummaries()
            status = "Synced generic check-ins. iPhone Screen Time reports stay private."
        } catch {
            status = "Sync failed: \(error.localizedDescription)"
        }
    }

    func loadMacSummaries() async {
        guard signedIn, enabled else { return }
        do {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.timeZone = .current
            dayFormatter.dateFormat = "yyyy-MM-dd"
            let date = dayFormatter.string(from: Date())
            let result = try await request(
                "/rest/v1/pause_usage_daily?select=category,seconds&user_id=eq.\(owner)&day=eq.\(date)"
            )
            guard let rows = result as? [[String: Any]] else { return }
            var totals: [String: Int] = [:]
            for row in rows {
                guard let category = row["category"] as? String,
                      let seconds = row["seconds"] as? Int else { continue }
                totals[category, default: 0] += seconds
            }
            macCategoryTotals = totals
        } catch {
            status = "Could not load Mac summaries: \(error.localizedDescription)"
        }
    }

    func sendBoard(_ text: String?) async {
        guard signedIn else {
            status = "Sign in to the cloud first."
            return
        }
        guard text == nil || (text!.count <= 280 && !text!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) else {
            status = "Message must be 1–280 characters."
            return
        }
        do {
            _ = try await request(
                "/rest/v1/pause_board_state?on_conflict=user_id",
                method: "POST",
                payload: [[
                    "user_id": owner,
                    "source": "manual",
                    "message": text == nil ? NSNull() : text!.uppercased() as Any
                ]],
                prefer: "resolution=merge-duplicates,return=minimal"
            )
            status = text == nil ? "Cloud board cleared." : "Cloud board message updated."
        } catch {
            status = "Could not send cloud message: \(error.localizedDescription)"
        }
    }

    enum CloudError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            if case .message(let message) = self { return message }
            return "Cloud error."
        }
    }
}

private enum PAUSEKeychain {
    static func save(_ value: String, key: String) {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pause.ios.cloud",
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pause.ios.cloud",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess,
              let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pause.ios.cloud",
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
