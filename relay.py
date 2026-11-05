#!/usr/bin/env python3
"""PAUSE LAN relay. Run: python3 relay.py --lan

Serves the Mac board on loopback, plus a paired remote controller on a
trusted local network. Never exposes raw ActivityWatch data to LAN clients.
"""
import argparse
import hmac
import ipaddress
import json
import secrets
import threading
from datetime import datetime, timezone
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

from bridge import Handler as LocalActivityHandler

ROOT = Path(__file__).resolve().parent
LOCK = threading.Lock()
BOARD = {"sequence": 0, "message": None, "source": None, "updated_at": None}
ALLOWED = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,?!+:/&@-\n")


def normalize_message(message):
    if not isinstance(message, str):
        return None
    message = message.upper().replace("\r", "").strip()
    if not message or len(message) > 280 or message.count("\n") > 8:
        return None
    if any(ch not in ALLOWED for ch in message):
        return None
    return message


def accepted_host(header, port, lan):
    if not header or header.count(":") != 1:
        return False
    name, given_port = header.lower().rsplit(":", 1)
    if given_port != str(port):
        return False
    if name in ("127.0.0.1", "localhost"):
        return True
    if not lan:
        return False
    try:
        address = ipaddress.ip_address(name)
        return address.version == 4 and address.is_private and not address.is_loopback
    except ValueError:
        return False


def loopback(address):
    return address in ("127.0.0.1", "::1")


class Handler(LocalActivityHandler):
    def response(self, code, payload):
        raw = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def valid_host(self):
        if accepted_host(self.headers.get("Host", ""), self.server.server_port, self.server.allow_lan):
            return True
        self.send_error(403, "Invalid Host")
        return False

    def do_GET(self):
        if not self.valid_host():
            return
        path = urlparse(self.path).path
        if path in ("/controller", "/controller.html", "/remote.js"):
            filename = "controller.html" if path == "/controller" else path.lstrip("/")
            data = (ROOT / filename).read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/javascript" if filename.endswith(".js") else "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if path == "/pause-api/board":
            if not loopback(self.client_address[0]):
                self.send_error(403, "Board state is only available on the Mac")
                return
            with LOCK:
                payload = BOARD.copy()
            return self.response(200, payload)
        if not loopback(self.client_address[0]):
            # The authenticated phone controller only needs the page and POST route.
            self.send_error(403, "Private Mac content")
            return
        # Existing PAUSE ActivityWatch API / original Vestaboard remain unchanged.
        return super().do_GET()

    def do_POST(self):
        if not self.valid_host():
            return
        if urlparse(self.path).path != "/pause-api/command":
            self.send_error(404)
            return
        origin = self.headers.get("Origin")
        if origin and origin != "http://" + self.headers.get("Host", ""):
            return self.response(403, {"error": "Cross-origin requests denied"})
        if not hmac.compare_digest(self.headers.get("X-PAUSE-Key", ""), self.server.pairing_key):
            return self.response(401, {"error": "Incorrect pairing code"})
        if self.headers.get("Content-Type", "").split(";")[0].strip().lower() != "application/json":
            return self.response(415, {"error": "JSON only"})
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 1 <= size <= 1024:
                return self.response(413, {"error": "Invalid request length"})
            payload = json.loads(self.rfile.read(size))
        except (ValueError, TypeError):
            return self.response(400, {"error": "Invalid JSON"})
        if not isinstance(payload, dict):
            return self.response(400, {"error": "Invalid request"})
        action = payload.get("action")
        if action not in ("message", "threshold", "clear", "ping"):
            return self.response(400, {"error": "Unknown action"})
        if action == "ping":
            return self.response(200, {"ok": True, "paired": True})
        message = None
        if action == "message":
            message = normalize_message(payload.get("message"))
            if message is None:
                return self.response(422, {"error": "Unsupported board message"})
        if action == "threshold":
            category = payload.get("category")
            if category not in ("social", "creative", "entertainment"):
                return self.response(422, {"error": "Unknown activity category"})
            message = {
                "social": "YOU REACHED YOUR LIMIT\n\nREADY TO STEP AWAY?",
                "creative": "YOU HAVE BEEN CREATING\nFOR A WHILE\n\nSTRETCH BREAK?",
                "entertainment": "TIME FOR A CHECK-IN\n\nKEEP WATCHING OR PAUSE?"
            }[category]
        with LOCK:
            BOARD["sequence"] += 1
            BOARD["message"] = message
            BOARD["source"] = action
            BOARD["updated_at"] = datetime.now(timezone.utc).isoformat()
            result = BOARD.copy()
        return self.response(200, {"ok": True, **result})


def main():
    parser = argparse.ArgumentParser(description="PAUSE local board and trusted LAN controller")
    parser.add_argument("--lan", action="store_true", help="Enable phone controller on trusted local Wi-Fi")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--activitywatch-url", default="http://127.0.0.1:5600")
    args = parser.parse_args()
    server = ThreadingHTTPServer(("0.0.0.0" if args.lan else "127.0.0.1", args.port), Handler)
    server.activitywatch_url = args.activitywatch_url
    server.allow_lan = args.lan
    server.pairing_key = secrets.token_urlsafe(24)
    print("PAUSE board: http://127.0.0.1:%s/" % args.port)
    print("Pairing key: %s" % server.pairing_key)
    if args.lan:
        print("Phone controller: http://YOUR-MAC-LOCAL-IP:%s/controller" % args.port)
        print("Trusted private Wi-Fi ONLY. Local HTTP is not encrypted.")
    else:
        print("Controller: http://127.0.0.1:%s/controller" % args.port)
        print("To use your phone on the same Wi-Fi, restart with: python3 relay.py --lan")
    print("No internet relay or cloud upload is used. Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
