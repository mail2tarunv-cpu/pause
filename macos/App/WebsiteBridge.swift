import Foundation
import Network

/// Private loopback-only endpoint for the PAUSE browser extension.
/// Example POST body: {"domain":"figma.com"} — never URLs or page titles.
final class WebsiteBridge {
    private let onDomain: (String?) -> Void
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.pause.browser.bridge")

    init(onDomain: @escaping (String?) -> Void) {
        self.onDomain = onDomain
    }

    func start(token: @escaping () -> String) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(rawValue: 8766)!
        )
        let localListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: 8766)!)
        localListener.newConnectionHandler = { [weak self] connection in
            guard let self else { connection.cancel(); return }
            connection.start(queue: self.queue)
            self.read(connection: connection, buffer: Data(), token: token)
        }
        localListener.start(queue: queue)
        listener = localListener
    }

    deinit { listener?.cancel() }

    private func read(connection: NWConnection, buffer: Data, token: @escaping () -> String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, done, error in
            guard let self else { connection.cancel(); return }
            var combined = buffer
            if let data { combined.append(data) }
            if combined.count > 8192 || error != nil {
                self.reply(connection, status: 413, origin: nil, body: #"{"error":"request too large"}"#)
                return
            }
            guard let request = String(data: combined, encoding: .utf8),
                  let separator = request.range(of: "\r\n\r\n") else {
                if done { connection.cancel() }
                else { self.read(connection: connection, buffer: combined, token: token) }
                return
            }
            let header = String(request[..<separator.lowerBound])
            let lines = header.components(separatedBy: "\r\n")
            let first = lines.first ?? ""
            var fields: [String: String] = [:]
            for line in lines.dropFirst() {
                guard let index = line.firstIndex(of: ":") else { continue }
                let name = String(line[..<index]).lowercased()
                // Ignore duplicate untrusted header names rather than crashing.
                if fields[name] == nil {
                    fields[name] = String(line[line.index(after: index)...])
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            let host = fields["host"] ?? ""
            let origin = fields["origin"] ?? ""
            let corsOrigin = self.isExtensionOrigin(origin) ? origin : nil
            guard host == "127.0.0.1:8766" || host == "localhost:8766" else {
                self.reply(connection, status: 403, origin: nil, body: #"{"error":"invalid host"}"#)
                return
            }
            if first == "OPTIONS /active-site HTTP/1.1", corsOrigin != nil {
                self.reply(connection, status: 204, origin: corsOrigin, body: "")
                return
            }
            guard first == "POST /active-site HTTP/1.1", corsOrigin != nil else {
                self.reply(connection, status: 403, origin: corsOrigin, body: #"{"error":"extension only"}"#)
                return
            }
            guard let provided = fields["x-pause-token"],
                  provided.count == 48, provided == token() else {
                self.reply(connection, status: 401, origin: corsOrigin, body: #"{"error":"not paired"}"#)
                return
            }
            guard let contentLength = Int(fields["content-length"] ?? ""),
                  contentLength > 0, contentLength <= 1024 else {
                self.reply(connection, status: 400, origin: corsOrigin, body: #"{"error":"invalid length"}"#)
                return
            }
            let bodyOffset = request[..<separator.upperBound].utf8.count
            let remaining = combined.count - bodyOffset
            guard remaining >= contentLength else {
                if done { connection.cancel() }
                else { self.read(connection: connection, buffer: combined, token: token) }
                return
            }
            let body = combined.subdata(in: bodyOffset..<(bodyOffset + contentLength))
            guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                self.reply(connection, status: 400, origin: corsOrigin, body: #"{"error":"invalid JSON"}"#)
                return
            }
            if json["domain"] is NSNull {
                self.onDomain(nil)
                self.reply(connection, status: 200, origin: corsOrigin, body: #"{"ok":true}"#)
                return
            }
            guard let domain = json["domain"] as? String,
                  let normalized = self.cleanDomain(domain) else {
                self.reply(connection, status: 422, origin: corsOrigin, body: #"{"error":"invalid domain"}"#)
                return
            }
            self.onDomain(normalized)
            self.reply(connection, status: 200, origin: corsOrigin, body: #"{"ok":true}"#)
        }
    }

    private func cleanDomain(_ value: String) -> String? {
        let domain = value.lowercased().hasPrefix("www.") ?
                     String(value.lowercased().dropFirst(4)) : value.lowercased()
        guard domain.count <= 150, domain.contains("."), !domain.hasPrefix("."),
              !domain.hasSuffix("."), !domain.contains(".."),
              domain.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-").contains($0)
              }) else { return nil }
        return domain
    }

    private func isExtensionOrigin(_ value: String) -> Bool {
        value.hasPrefix("chrome-extension://") ||
        value.hasPrefix("moz-extension://") ||
        value.hasPrefix("safari-web-extension://")
    }

    private func reply(_ connection: NWConnection, status: Int, origin: String?, body: String) {
        let reason = [200: "OK", 204: "No Content", 400: "Bad Request",
                      401: "Unauthorized", 403: "Forbidden",
                      413: "Payload Too Large", 422: "Unprocessable Content"][status] ?? "Error"
        let data = Data(body.utf8)
        var text = "HTTP/1.1 \(status) \(reason)\r\n"
        text += "Content-Type: application/json\r\n"
        text += "Cache-Control: no-store\r\n"
        text += "X-Content-Type-Options: nosniff\r\n"
        text += "Content-Length: \(data.count)\r\n"
        text += "Connection: close\r\n"
        if let origin {
            text += "Access-Control-Allow-Origin: \(origin)\r\n"
            text += "Vary: Origin\r\n"
            text += "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
            text += "Access-Control-Allow-Headers: content-type,x-pause-token\r\n"
        }
        text += "\r\n"
        var response = Data(text.utf8)
        response.append(data)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
