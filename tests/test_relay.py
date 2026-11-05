import json
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from relay import Handler, BOARD, LOCK, accepted_host, normalize_message


class RelayTests(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.server.allow_lan = False
        self.server.pairing_key = "test-only-unguessable-key"
        self.server.activitywatch_url = "http://127.0.0.1:5600"
        self.url = "http://127.0.0.1:%d" % self.server.server_port
        self.worker = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.worker.start()
        with LOCK:
            BOARD.update(sequence=0, message=None, source=None, updated_at=None)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.worker.join(timeout=2)

    def command(self, action, **fields):
        data = json.dumps({"action": action, **fields}).encode()
        req = Request(
            self.url + "/pause-api/command",
            data=data,
            headers={"Content-Type": "application/json",
                     "X-PAUSE-Key": "test-only-unguessable-key"},
            method="POST")
        with urlopen(req) as response:
            return json.load(response)

    def test_pair_does_not_change_board(self):
        before = self.command("ping")
        self.assertTrue(before["paired"])
        self.assertEqual(BOARD["sequence"], 0)

    def test_controller_to_board(self):
        sent = self.command("message", message="TAKE A BREAK")
        self.assertEqual(sent["message"], "TAKE A BREAK")
        with urlopen(self.url + "/pause-api/board") as response:
            board = json.load(response)
        self.assertEqual(board["message"], "TAKE A BREAK")
        self.assertEqual(board["sequence"], 1)

    def test_clear(self):
        self.command("message", message="HELLO")
        cleared = self.command("clear")
        self.assertIsNone(cleared["message"])
        self.assertEqual(cleared["sequence"], 2)

    def test_minimal_threshold(self):
        sent = self.command("threshold", category="social")
        self.assertIn("STEP AWAY", sent["message"])
        self.assertNotIn("instagram", json.dumps(sent).lower())

    def test_wrong_key_fails(self):
        req = Request(self.url + "/pause-api/command",
            data=b'{"action":"clear"}', method="POST",
            headers={"Content-Type": "application/json", "X-PAUSE-Key": "wrong"})
        with self.assertRaises(HTTPError) as result:
            urlopen(req)
        self.assertEqual(result.exception.code, 401)
        self.assertEqual(BOARD["sequence"], 0)

    def test_rejects_non_board_characters(self):
        self.assertIsNone(normalize_message("<script>alert(1)</script>"))
        self.assertIsNone(normalize_message("HELLO 😊"))
        self.assertEqual(normalize_message("hello world"), "HELLO WORLD")

    def test_host_rules(self):
        self.assertTrue(accepted_host("127.0.0.1:8765", 8765, False))
        self.assertFalse(accepted_host("192.168.1.4:8765", 8765, False))
        self.assertTrue(accepted_host("192.168.1.4:8765", 8765, True))
        self.assertFalse(accepted_host("evil.example:8765", 8765, True))


if __name__ == "__main__":
    unittest.main()
