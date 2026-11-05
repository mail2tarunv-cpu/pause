import Foundation

/// Local-network transport shared by the app and DeviceActivity extension.
/// The monitor persists a pending event before making a best-effort network
/// request. The foreground app retries the event when it next becomes active.
enum PAUSETransport {
    static let groupID = "group.com.example.pause"
    static let bridgeKey = "bridgeAddress"
    static let pairingKey = "pairingCode"
    static let pendingKey = "pendingThreshold"
    static let historyKey = "thresholdHistory"
    static let forwardKey = "forwardThresholds"

    struct PendingThreshold: Codable {
        let id: String
        let category: String
        let occurredAt: Date
    }

    enum TransportError: LocalizedError {
        case missingConnection, invalidAddress, unauthorized, rejected(Int)

        var errorDescription: String? {
            switch self {
            case .missingConnection: return "Enter the Mac address and pairing code first."
            case .invalidAddress: return "Use a trusted local address such as http://192.168.1.10:8765."
            case .unauthorized: return "The pairing code was rejected."
            case .rejected(let code): return "PAUSE returned HTTP \(code)."
            }
        }
    }

    static var preferences: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    static func configure(address: String, code: String) {
        preferences?.set(address.trimmingCharacters(in: .whitespacesAndNewlines), forKey: bridgeKey)
        preferences?.set(code.trimmingCharacters(in: .whitespacesAndNewlines), forKey: pairingKey)
    }

    static func endpoint() throws -> URL {
        guard let raw = preferences?.string(forKey: bridgeKey), !raw.isEmpty else {
            throw TransportError.missingConnection
        }
        guard var components = URLComponents(string: raw),
              components.scheme == "http",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              let host = components.host,
              components.port == 8765 else {
            throw TransportError.invalidAddress
        }
        // LAN-only prototype. Never send pairing credentials to public hosts.
        let octets = host.split(separator: ".").compactMap { Int($0) }
        let isIPv4 = octets.count == 4 &&
            octets.allSatisfy { (0...255).contains($0) }
        let isPrivate = isIPv4 && (
            octets[0] == 10 ||
            (octets[0] == 172 && (16...31).contains(octets[1])) ||
            (octets[0] == 192 && octets[1] == 168) ||
            octets[0] == 127
        )
        guard isPrivate || host == "localhost" else {
            throw TransportError.invalidAddress
        }
        components.path = "/pause-api/command"
        guard let endpoint = components.url else { throw TransportError.invalidAddress }
        return endpoint
    }

    static func send(action: String, category: String? = nil, message: String? = nil) async throws {
        guard let key = preferences?.string(forKey: pairingKey), !key.isEmpty else {
            throw TransportError.missingConnection
        }
        let endpoint = try endpoint()
        var body: [String: String] = ["action": action]
        if let category { body["category"] = category }
        if let message { body["message"] = message }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-PAUSE-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw TransportError.rejected(0)
        }
        if response.statusCode == 401 { throw TransportError.unauthorized }
        guard (200...299).contains(response.statusCode) else {
            throw TransportError.rejected(response.statusCode)
        }
    }

    static func stageThreshold(category: String) {
        let event = PendingThreshold(id: UUID().uuidString, category: category, occurredAt: Date())
        guard let data = try? JSONEncoder().encode(event) else { return }
        if preferences?.bool(forKey: forwardKey) == true {
            preferences?.set(data, forKey: pendingKey)
        }
        var records = history()
        records.insert(event, at: 0)
        if let encoded = try? JSONEncoder().encode(Array(records.prefix(40))) {
            preferences?.set(encoded, forKey: historyKey)
        }
    }

    static func history() -> [PendingThreshold] {
        guard let data = preferences?.data(forKey: historyKey),
              let records = try? JSONDecoder().decode([PendingThreshold].self, from: data) else {
            return []
        }
        return records
    }

    static func clearHistory() {
        preferences?.removeObject(forKey: historyKey)
    }

    static func flushPending() async throws {
        guard preferences?.bool(forKey: forwardKey) == true else { return }
        guard let data = preferences?.data(forKey: pendingKey),
              let event = try? JSONDecoder().decode(PendingThreshold.self, from: data) else {
            return
        }
        // An old alert should never reappear hours or days later.
        guard Date().timeIntervalSince(event.occurredAt) < 3600 else {
            if preferences?.data(forKey: pendingKey) == data {
                preferences?.removeObject(forKey: pendingKey)
            }
            return
        }
        try await send(action: "threshold", category: event.category)
        // Don't erase a newer event that arrived while this request was in flight.
        if preferences?.data(forKey: pendingKey) == data {
            preferences?.removeObject(forKey: pendingKey)
        }
    }
}
