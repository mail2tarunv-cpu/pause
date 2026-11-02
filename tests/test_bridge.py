import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bridge import aggregate, category, host_from_url

BASE = datetime(2026, 11, 2, 16, 0, tzinfo=timezone.utc)


def event(offset, duration, data):
    return {
        "timestamp": (BASE + timedelta(seconds=offset)).isoformat(),
        "duration": duration,
        "data": data,
    }


class ActivityAggregationTests(unittest.TestCase):
    def test_single_app_aggregated(self):
        windows = [event(0, 60, {"app": "Figma", "title": "Private project"})]
        out = aggregate(windows, [], [], BASE, BASE+timedelta(seconds=60), has_afk=False)
        self.assertEqual(out["total_seconds"], 60)
        self.assertEqual(out["current"]["name"], "Figma")
        self.assertEqual(out["current"]["session_seconds"], 60)
        self.assertNotIn("Private project", str(out))

    def test_browser_web_replaces_not_doubles(self):
        windows = [event(0, 60, {"app": "Google Chrome"})]
        web = [event(20, 30, {"url": "https://www.instagram.com/private/path?query=secret"})]
        out = aggregate(windows, web, [], BASE, BASE+timedelta(seconds=60), has_afk=False)
        self.assertEqual(out["total_seconds"], 60)
        totals = {item["id"]:item["seconds"] for item in out["items"]}
        self.assertEqual(totals["site:instagram.com"],30)
        self.assertEqual(totals["app:google chrome"],30)
        self.assertNotIn("private/path",str(out))

    def test_afk_filters_idle(self):
        windows = [event(0, 60, {"app": "Figma"})]
        afk = [event(0, 35, {"status": "not-afk"}), event(35, 25, {"status": "afk"})]
        out = aggregate(windows, [], afk, BASE, BASE+timedelta(seconds=60), has_afk=True)
        self.assertEqual(out["total_seconds"],35)
        self.assertEqual(out["current"],None)

    def test_unknown_afk_span_is_not_counted(self):
        windows = [event(0, 60, {"app": "Figma"})]
        out = aggregate(windows, [], [], BASE, BASE+timedelta(seconds=60), has_afk=True)
        self.assertEqual(out["total_seconds"],0)

    def test_current_stale(self):
        out = aggregate([event(0,60,{"app":"Figma"})],[],[],BASE,BASE+timedelta(seconds=600),has_afk=False)
        self.assertIsNone(out["current"])

    def test_subdomains_and_invalid_hosts(self):
        self.assertEqual(host_from_url("https://www.instagram.com/accounts/foo?token=test"), "instagram.com")
        self.assertEqual(category("site:music.youtube.com", "music.youtube.com"),"entertainment")
        self.assertIsNone(host_from_url("file:///Users/user/secret"))
        self.assertIsNone(host_from_url("javascript:alert(1)"))

    def test_web_ignored_when_non_browser_foreground(self):
        windows=[event(0,60,{"app":"Figma"})]
        web=[event(10,40,{"url":"https://instagram.com/reels"})]
        out=aggregate(windows,web,[],BASE,BASE+timedelta(seconds=60),has_afk=False)
        self.assertEqual(out["total_seconds"],60)
        self.assertEqual(len(out["items"]),1)
        self.assertEqual(out["current"]["name"],"Figma")


if __name__ == "__main__":
    unittest.main()
