import Foundation
import Combine
import Security

/// A minimal authenticated Supabase REST client. Only category/day totals
/// and board messages are synchronized; raw app/site records never leave Mac.
/// Set up a new PAUSE Supabase project and run supabase/schema.sql first.
@MainActor
final class MacCloudSync: ObservableObject {
    @Published var projectURL = UserDefaults.standard.string(forKey: "pause-cloud-url") ?? ""
    @Published var publishableKey = UserDefaults.standard.string(forKey: "pause-cloud-key") ?? ""
    @Published var email = ""
    @Published var password = ""
    @Published var syncEnabled = UserDefaults.standard.bool(forKey: "pause-cloud-enabled")
    @Published var status = "Not connected"
    @Published var authenticated = false

    private weak var activity: MacActivityStore?
    private var task: Task<Void, Never>?
    private var accessToken = SecureToken.load("access") ?? ""
    private var refreshToken = SecureToken.load("refresh") ?? ""
    private var expiresAt = UserDefaults.standard.double(forKey: "pause-cloud-expires")
    private var userId = UserDefaults.standard.string(forKey: "pause-cloud-userid") ?? ""
    private var revision = ""

    private let deviceId: String = {
        if let saved = UserDefaults.standard.string(forKey: "pause-mac-device-id") { return saved }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: "pause-mac-device-id")
        return value
    }()

    init() { authenticated = !accessToken.isEmpty && !userId.isEmpty }

    func attach(activity: MacActivityStore) {
        self.activity = activity
        guard task == nil else { return }
        task = Task { [weak self] in
            while let self, !Task.isCancelled {
                if self.syncEnabled && self.authenticated {
                    await self.synchronize()
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    func setSyncEnabled(_ value: Bool) {
        syncEnabled = value
        UserDefaults.standard.set(value, forKey: "pause-cloud-enabled")
        if value { Task { await synchronize() } }
    }

    private var base: String? {
        let trimmed = projectURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed), url.scheme == "https",
              let host = url.host,
              host.hasSuffix(".supabase.co") || host.hasSuffix(".supabase.in"),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty else { return nil }
        return trimmed
    }

    private func request(
        path: String,
        method: String = "GET",
        payload: Any? = nil,
        auth: Bool = true,
        headers: [String: String] = [:]
    ) async throws -> Any {
        guard let base, publishableKey.hasPrefix("sb_publishable_") else { throw SyncError.configuration }
        let url = URL(string: base + path)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 12
        req.setValue(publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth {
            let token = try await validAccessToken()
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        for (key, value) in headers { req.setValue(value, forHTTPHeaderField: key) }
        if let payload { req.httpBody = try JSONSerialization.data(withJSONObject: payload) }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SyncError.network }
        guard (200...299).contains(http.statusCode) else {
            throw SyncError.server(http.statusCode)
        }
        return data.isEmpty ? [:] : (try JSONSerialization.jsonObject(with: data))
    }

    private func validAccessToken() async throws -> String {
        if !accessToken.isEmpty && Date().timeIntervalSince1970 < expiresAt - 90 {
            return accessToken
        }
        guard !refreshToken.isEmpty else { throw SyncError.signedOut }
        let refreshed = try await request(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            payload: ["refresh_token": refreshToken],
            auth: false
        )
        try setSession(refreshed)
        return accessToken
    }

    private func setSession(_ json: Any) throws {
        guard let object = json as? [String: Any],
              let access = object["access_token"] as? String,
              let refresh = object["refresh_token"] as? String,
              let expires = object["expires_in"] as? Int,
              let user = object["user"] as? [String: Any],
              let id = user["id"] as? String else { throw SyncError.invalidSession }
        accessToken = access
        refreshToken = refresh
        expiresAt = Date().timeIntervalSince1970 + Double(expires)
        userId = id
        SecureToken.save(access, as: "access")
        SecureToken.save(refresh, as: "refresh")
        UserDefaults.standard.set(expiresAt, forKey: "pause-cloud-expires")
        UserDefaults.standard.set(userId, forKey: "pause-cloud-userid")
        authenticated = true
        password = ""
    }

    func signIn() async {
        guard base != nil, !publishableKey.isEmpty, !email.isEmpty, !password.isEmpty else {
            status = "Enter your Supabase URL, publishable key, email and password."
            return
        }
        UserDefaults.standard.set(projectURL, forKey: "pause-cloud-url")
        UserDefaults.standard.set(publishableKey, forKey: "pause-cloud-key")
        status = "Signing in…"
        do {
            let object = try await request(
                path: "/auth/v1/token?grant_type=password",
                method: "POST",
                payload: ["email": email, "password": password],
                auth: false
            )
            try setSession(object)
            status = "Signed in. Cloud sync is optional."
            await synchronize()
        } catch {
            status = "Sign-in failed: \(error.localizedDescription)"
        }
    }

    func signOut() {
        accessToken = ""
        refreshToken = ""
        userId = ""
        expiresAt = 0
        authenticated = false
        setSyncEnabled(false)
        SecureToken.delete("access")
        SecureToken.delete("refresh")
        UserDefaults.standard.removeObject(forKey: "pause-cloud-userid")
        UserDefaults.standard.removeObject(forKey: "pause-cloud-expires")
        status = "Signed out. Local tracking continues."
        activity?.cloudBoardMessage = nil
    }

    private func synchronize() async {
        guard authenticated, syncEnabled, let activity else { return }
        do {
            let id = deviceId
            let owner = userId
            let now = ISO8601DateFormatter().string(from: Date())
            _ = try await request(
                path: "/rest/v1/pause_devices?on_conflict=user_id,id",
                method: "POST",
                payload: [[
                    "id": id, "user_id": owner,
                    "kind": "mac", "label": "PAUSE for Mac", "last_seen": now
                ]],
                headers: ["Prefer": "resolution=merge-duplicates,return=minimal"]
            )
            // Explicit consent uploads only four daily category totals.
            for (category, seconds) in activity.byCategory {
                _ = try await request(
                    path: "/rest/v1/pause_usage_daily?on_conflict=user_id,device_id,day,category",
                    method: "POST",
                    payload: [[
                        "user_id": owner, "device_id": id,
                        "day": MacActivityStore.today(), "category": category,
                        "seconds": seconds
                    ]],
                    headers: ["Prefer": "resolution=merge-duplicates,return=minimal"]
                )
            }
            let json = try await request(
                path: "/rest/v1/pause_board_state?select=message,updated_at&user_id=eq.\(owner)&limit=1"
            )
            if let rows = json as? [[String: Any]], let state = rows.first,
               let time = state["updated_at"] as? String, time != revision {
                revision = time
                activity.cloudBoardMessage = state["message"] as? String
            }
            status = "Synced (category totals only)"
        } catch {
            status = "Sync failed: \(error.localizedDescription)"
        }
    }

    enum SyncError: LocalizedError {
        case configuration, signedOut, invalidSession, network, server(Int)
        var errorDescription: String? {
            switch self {
            case .configuration: return "Check your project URL and publishable key."
            case .signedOut: return "Sign in again."
            case .invalidSession: return "Unexpected auth response."
            case .network: return "Network unavailable."
            case .server(let code): return "Server returned HTTP \(code)."
            }
        }
    }
}

/// Tokens are kept in the macOS Keychain, never in UserDefaults or GitHub.
private enum SecureToken {
    static func save(_ text: String, as name: String) {
        delete(name)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pause.mac.cloud",
            kSecAttrAccount as String: name,
            kSecValueData as String: Data(text.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    static func load(_ name: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pause.mac.cloud",
            kSecAttrAccount as String: name,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func delete(_ name: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pause.mac.cloud",
            kSecAttrAccount as String: name
        ]
        SecItemDelete(query as CFDictionary)
    }
}
