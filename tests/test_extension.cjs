const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { pauseDomain } = require("../browser-extension/domain.js");

const pairs = [
  ["https://www.instagram.com/direct/inbox/?secret=1", "instagram.com"],
  ["https://figma.com/file/123?token=sensitive#fragment", "figma.com"],
  ["https://docs.google.com/document/d/123", "docs.google.com"],
  ["chrome://settings", null],
  ["file:///Users/person/Documents/secret", null],
  ["about:blank", null],
  ["http://localhost:8765", null],
  ["https://127.0.0.1:8765/secret", null],
  ["not a url", null],
  [null, null]
];
for (const [input, expected] of pairs) {
  assert.equal(pauseDomain(input), expected, "Incorrect domain for " + input);
}

const manifest = JSON.parse(
  fs.readFileSync(path.join(__dirname, "../browser-extension/manifest.json"), "utf8")
);
assert.equal(manifest.manifest_version, 3);
assert.ok(manifest.permissions.includes("tabs"));
assert.ok(!manifest.permissions.includes("history"));
assert.ok(!manifest.permissions.includes("cookies"));
assert.ok(!manifest.permissions.includes("webRequest"));
assert.ok(manifest.host_permissions.every(p => p.startsWith("http://127.0.0.1:8766/")));

const schema = fs.readFileSync(path.join(__dirname, "../supabase/schema.sql"), "utf8");
for (const name of ["pause_devices", "pause_usage_daily", "pause_board_state", "pause_nudge_events"]) {
  assert.match(schema, new RegExp("alter table public\\." + name + " enable row level security", "i"));
}
assert.match(schema, /auth\.uid\(\)/);
assert.match(schema, /with check/i);
assert.ok(!schema.includes("service_role"), "Never use service role secrets in client schema");

const cloudClient = fs.readFileSync(path.join(__dirname, "../cloud/client.js"), "utf8");
assert.ok(cloudClient.includes("sessionStorage"));
assert.ok(!cloudClient.includes("service_role"));
assert.ok(!cloudClient.includes("sb_secret_"));
console.log("PAUSE extension privacy, API shape and database access checks passed.");
