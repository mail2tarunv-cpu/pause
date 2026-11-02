#!/usr/bin/env python3
"""PAUSE: local-only ActivityWatch bridge and static board server.

No third-party dependencies. Binds to 127.0.0.1; never uploads activity.
Run: python3 bridge.py
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
from pathlib import Path
import re
import socket
import threading
from urllib.error import URLError, HTTPError
from urllib.parse import quote, urlencode, urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
DEFAULT_AW = "http://127.0.0.1:5600"
BROWSERS = ("chrome", "chromium", "firefox", "safari", "edge", "arc", "brave", "opera", "vivaldi", "dia browser")
SOCIAL = ("instagram.com", "facebook.com", "tiktok.com", "reddit.com", "x.com", "twitter.com", "threads.net", "snapchat.com", "pinterest.com")
ENTERTAINMENT = ("youtube.com", "netflix.com", "twitch.tv", "disneyplus.com", "hulu.com", "primevideo.com", "max.com")
CREATIVE = ("figma.com", "canva.com", "notion.so", "docs.google.com", "github.com", "linear.app", "miro.com", "codepen.io")
LOCK = threading.Lock()
CACHE = {"at": None, "value": None}


def is_browser(name):
    n = name.lower()
    return any(b in n for b in BROWSERS)


def category(item_id, name):
    n = name.lower()
    host = item_id[5:] if item_id.startswith("site:") else ""
    if host:
        if any(host == s or host.endswith("." + s) for s in SOCIAL):
            return "social"
        if any(host == s or host.endswith("." + s) for s in ENTERTAINMENT):
            return "entertainment"
        if any(host == s or host.endswith("." + s) for s in CREATIVE):
            return "creative"
        return "other"
    if any(x in n for x in ("figma", "sketch", "photoshop", "illustrator", "blender", "xcode", "visual studio", "cursor", "code", "terminal", "obsidian", "notion", "keynote", "pages")):
        return "creative"
    if any(x in n for x in ("discord", "telegram", "slack")):
        return "social"
    if any(x in n for x in ("spotify", "steam", "vlc", "netflix")):
        return "entertainment"
    return "other"


def as_datetime(value):
    if not value or not isinstance(value, str):
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            return None
        return dt.astimezone(timezone.utc)
    except ValueError:
        return None


def intervals(events, start, end):
    result = []
    for event in events:
        ts = as_datetime(event.get("timestamp"))
        try:
            duration = float(event.get("duration", 0))
        except (ValueError, TypeError):
            continue
        if ts is None or not 0 < duration <= 86400 * 3:
            continue
        a, b = max(start, ts), min(end, ts + timedelta(seconds=duration))
        if a < b:
            result.append((a, b, event.get("data") or {}))
    return sorted(result, key=lambda x: x[0])


def host_from_url(raw):
    if not isinstance(raw, str):
        return None
    if not raw.startswith(("https://", "http://")):
        return None
    parsed = urlparse(raw)
    host = (parsed.hostname or "").lower().removeprefix("www.")
    if not host or len(host) > 180 or not re.fullmatch(r"[a-z0-9.\-]+", host):
        return None
    return host


def window_identity(data):
    app = str(data.get("app") or "").strip()[:90]
    if not app:
        return None
    return {"id": "app:" + app.casefold(), "name": app, "category": category("app:" + app.casefold(), app)}


def web_identity(data):
    host = host_from_url(data.get("url", ""))
    if not host:
        return None
    return {"id": "site:" + host, "name": host, "category": category("site:" + host, host)}


def aggregate(window_events, web_events, afk_events, start, end, has_afk=True):
    """Use one foreground source per instant. Web takes precedence for browser windows.

    If AFK watcher exists, only count its not-afk spans. A timeline sweep prevents
    double-counting browser and window events, or overlapping heartbeat events.
    """
    windows = intervals(window_events, start, end)
    webs = intervals(web_events, start, end)
    afks = intervals(afk_events, start, end)
    boundaries = {start, end}
    for source in (windows, webs, afks):
        for a, b, _ in source:
            boundaries.add(a)
            boundaries.add(b)
    boundaries = sorted(boundaries)
    positions = [0, 0, 0]
    running = [[], [], []]
    sources = [windows, webs, afks]

    def at(i, stamp):
        source = sources[i]
        while positions[i] < len(source) and source[positions[i]][0] <= stamp:
            running[i].append(source[positions[i]])
            positions[i] += 1
        running[i] = [entry for entry in running[i] if entry[1] > stamp]
        return running[i][-1][2] if running[i] else None

    totals = defaultdict(float)
    labels = {}
    timeline = []
    for a, b in zip(boundaries, boundaries[1:]):
        seconds = (b - a).total_seconds()
        if seconds <= 0:
            continue
        win, web, afk = at(0, a), at(1, a), at(2, a)
        if has_afk and (not afk or afk.get("status") != "not-afk"):
            continue
        identity = window_identity(win) if win else None
        if web and (identity is None or is_browser(identity["name"])):
            identity = web_identity(web) or identity
        if identity is None:
            continue
        key = identity["id"]
        totals[key] += seconds
        labels[key] = identity
        if timeline and timeline[-1][2] == key and a <= timeline[-1][1] + timedelta(seconds=15):
            timeline[-1] = (timeline[-1][0], b, key, timeline[-1][3] + seconds)
        else:
            timeline.append((a, b, key, seconds))
    current = None
    if timeline and (end - timeline[-1][1]).total_seconds() <= 45:
        a, b, key, session_seconds = timeline[-1]
        current = {**labels[key], "session_seconds": round(session_seconds), "seconds_today": round(totals[key])}
    items = [{**labels[k], "seconds": round(v)} for k, v in totals.items() if v >= 1]
    items.sort(key=lambda v: v["seconds"], reverse=True)
    return {
        "total_seconds": round(sum(totals.values())),
        "items": items[:35],
        "current": current,
        "has_activity": bool(timeline)
    }


def aw_json(base, path, query=None):
    base = base.rstrip("/")
    url = base + path + ("?" + urlencode(query) if query else "")
    request = Request(url, headers={"Accept": "application/json", "User-Agent": "PAUSE/2.0"})
    with urlopen(request, timeout=3.5) as response:
        return json.load(response)


def collect(base=DEFAULT_AW, now=None):
    now = now or datetime.now(timezone.utc)
    midnight_local = now.astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
    start = midnight_local.astimezone(timezone.utc)
    try:
        buckets = aw_json(base, "/api/0/buckets/")
    except (URLError, HTTPError, TimeoutError, ValueError, OSError):
        return {"connected": False, "error": "ActivityWatch is not responding on localhost:5600.", "updated_at": now.isoformat(), "buckets": {"window": False, "afk": False, "web": False}}
    hostname = socket.gethostname().lower()
    groups = {"window": [], "web": [], "afk": []}
    for key, meta in buckets.items():
        bucket_host = str((meta or {}).get("hostname") or "").lower()
        if bucket_host and bucket_host != hostname:
            continue
        for typ, prefix in (("window", "aw-watcher-window_"), ("web", "aw-watcher-web"), ("afk", "aw-watcher-afk_")):
            if key.startswith(prefix):
                groups[typ].append(key)
    # On installations whose hostname representation differs, use a unique bucket.
    if not groups["window"]:
        possible = [k for k in buckets if k.startswith("aw-watcher-window_")]
        if len(possible) == 1:
            groups["window"] = possible
    if not groups["afk"]:
        possible = [k for k in buckets if k.startswith("aw-watcher-afk_")]
        if len(possible) == 1:
            groups["afk"] = possible
    events = {"window": [], "web": [], "afk": []}
    for typ, names in groups.items():
        for name in names:
            try:
                events[typ].extend(aw_json(base, "/api/0/buckets/" + quote(name, safe="") + "/events", {"start": start.isoformat(), "end": now.isoformat(), "limit": -1}))
            except (URLError, HTTPError, TimeoutError, ValueError, OSError):
                pass
    active = bool(groups["afk"])
    summary = aggregate(events["window"], events["web"], events["afk"], start, now, has_afk=active)
    return {
        "connected": True, "updated_at": now.isoformat(),
        "buckets": {k: bool(v) for k, v in groups.items()},
        "error": None if groups["window"] else "No window watcher detected. Check ActivityWatch permissions.",
        "warning": None if active else "AFK watcher missing: active time may include idle time.",
        **summary
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("[%s] %s" % (self.log_date_time_string(), fmt % args))

    def do_GET(self):
        # Defend the unauthenticated loopback endpoint from DNS rebinding.
        allowed_hosts = {f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"}
        if self.headers.get("Host", "").lower() not in allowed_hosts:
            self.send_error(403, "Invalid Host")
            return
        path = urlparse(self.path).path
        if path == "/pause-api/status":
            with LOCK:
                now = datetime.now(timezone.utc)
                if CACHE["at"] is None or (now - CACHE["at"]).total_seconds() >= 8:
                    CACHE["value"] = collect(self.server.activitywatch_url, now)
                    CACHE["at"] = now
                data = CACHE["value"]
            raw = json.dumps(data).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return

        if path in ("/", "/index.html", "/v2.js", "/v2.css"):
            name = "index.html" if path == "/" else path.lstrip("/")
            file = ROOT / name
            if not file.is_file():
                self.send_error(404)
                return
            data = file.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", mimetypes.guess_type(str(file))[0] or "text/plain")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        self.send_error(404)


def main():
    parser = argparse.ArgumentParser(description="Run PAUSE locally with ActivityWatch activity tracking")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--activitywatch-url", default=DEFAULT_AW)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.activitywatch_url = args.activitywatch_url
    print("PAUSE live board: http://127.0.0.1:%s" % args.port)
    print("Data stays on this Mac. Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
