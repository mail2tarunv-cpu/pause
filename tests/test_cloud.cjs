const assert = require("node:assert/strict");
const vm = require("node:vm");
const fs = require("node:fs");
const path = require("node:path");

function storage() {
  const entries = new Map();
  return {
    getItem: key => entries.get(key) ?? null,
    setItem: (key, value) => entries.set(key, String(value)),
    removeItem: key => entries.delete(key),
    clear: () => entries.clear()
  };
}

(async () => {
  const calls = [];
  const context = {
    window: {},
    URL,
    AbortSignal,
    localStorage: storage(),
    sessionStorage: storage(),
    fetch: async (url, options) => {
      calls.push({ url, ...options });
      let body = null;
      if (url.includes("grant_type=password")) {
        body = {
          access_token: "test-access", refresh_token: "test-refresh",
          expires_in: 3600, user: { id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" }
        };
      } else if (url.includes("pause_board_state?select")) {
        body = [{
          message: "HELLO PAUSE", source: "manual",
          updated_at: "2026-11-16T12:00:00Z"
        }];
      } else if (url.includes("pause_usage_daily?")) {
        body = [{ day: "2026-11-16", category: "creative", seconds: 120 }];
      } else if (url.includes("pause_devices?")) {
        body = [];
      } else if (url.includes("grant_type=refresh_token")) {
        body = {
          access_token: "refreshed", refresh_token: "refreshed-refresh",
          expires_in: 3600, user: { id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" }
        };
      }
      return {
        ok: true, status: 200,
        text: async () => body === null ? "" : JSON.stringify(body)
      };
    }
  };
  const source = fs.readFileSync(path.join(__dirname, "../cloud/client.js"), "utf8");
  vm.runInNewContext(source, context);
  const client = context.window.PauseCloud;

  assert.equal(client.isSignedIn, false);
  assert.rejects(client.sendBoard("NO AUTH"));
  assert.throws(() => client.configure("http://evil.test", "sb_publishable_abc"));
  assert.throws(() => client.configure("https://project.supabase.co", "sb_secret_do_not_use"));
  client.configure("https://project.supabase.co", "sb_publishable_demo_public_key");

  await client.signIn("test@example.com", "password-not-stored");
  assert.equal(client.userId, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
  assert.equal(client.isSignedIn, true);
  assert.equal(context.localStorage.getItem("pause-cloud-session-v1"), null);
  assert.ok(context.sessionStorage.getItem("pause-cloud-session-v1")?.includes("test-access"));

  await client.sendBoard("take a pause");
  const request = calls.find(c => c.url.includes("pause_board_state?on_conflict"));
  assert.ok(request);
  assert.equal(request.headers.Authorization, "Bearer test-access");
  const sent = JSON.parse(request.body)[0];
  assert.equal(sent.user_id, client.userId);
  assert.equal(sent.message, "TAKE A PAUSE");

  const board = await client.getBoard();
  assert.equal(board.message, "HELLO PAUSE");
  await client.getDaily();
  await client.getDevices();
  assert.ok(calls.filter(c => c.url.includes("rest/v1")).every(c =>
    c.headers.Authorization === "Bearer test-access"));

  await client.sendBoard(null);
  client.signOut();
  assert.equal(client.isSignedIn, false);
  assert.equal(context.sessionStorage.getItem("pause-cloud-session-v1"), null);
  console.log("PAUSE cloud auth, owner scoping, board messages, and session storage checks passed.");
})().catch(error => { console.error(error); process.exitCode = 1; });
