const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const load = p => fs.readFileSync(path.join(__dirname, "..", p), "utf8");

const app = load("ios/App/PAUSECompanionApp.swift");
const palette = load("ios/App/PAUSETheme.swift");
const home = load("ios/App/PAUSEHomeView.swift");
const rules = load("ios/App/PAUSERulesView.swift");
const board = load("ios/App/PAUSEBoardView.swift");
const settings = load("ios/App/PAUSESettingsView.swift");
const report = load("ios/Report/PAUSEReportExtension.swift");
const mac = load("macos/App/MacDashboard.swift");
const macApp = load("macos/App/PAUSEMacApp.swift");
const browser = load("browser-extension/popup.css");

assert.match(app, /TabView/);
assert.equal((app.match(/NavigationStack/g) || []).length, 4,
  "All four tabs should own independent native navigation stacks");
assert.doesNotMatch(app, /preferredColorScheme\(\.light\)/);

for (const [name, file] of [
  ["Today", home], ["Rules", rules], ["Board", board], ["Settings", settings]
]) {
  assert.match(file, /\.navigationTitle\(/, name + " needs a native navigation title");
  assert.match(file, /\.listStyle\(\.insetGrouped\)|\.formStyle\(\.grouped\)/,
    name + " should use native grouped sections");
  assert.doesNotMatch(file, /PAUSECard|PAUSEKicker|PAUSEHeader|\.background\(Color\(red:/,
    name + " should not use legacy hard-coded card styles");
}
assert.match(home, /DeviceActivityReport\(/);
assert.match(rules, /\.familyActivityPicker\(/);
assert.match(rules, /Stepper\(/);
assert.match(board, /TextEditor\(/);
assert.match(board, /Array\(repeating: " ", count: 132\)/);
assert.match(board, /boardLayout\.overflow/);
assert.match(settings, /confirmationDialog/);
assert.match(settings, /SecureField\(/);
assert.match(report, /ProgressView\(/);
assert.doesNotMatch(report, /Color\(red: 0\.94, green: 0\.92/,
  "Protected Screen Time report should not force a warm card in Dark Mode");
assert.match(palette, /systemGroupedBackground/);
assert.match(palette, /Color\.primary/);
assert.match(palette, /Color\.secondary/);

assert.match(mac, /NavigationSplitView/);
assert.match(mac, /\.listStyle\(\.sidebar\)/);
assert.match(mac, /\.toolbar/);
assert.match(mac, /Form \{/);
assert.match(mac, /GroupBox/);
assert.match(mac, /ProgressView/);
assert.match(macApp, /MenuBarExtra/);
assert.match(macApp, /openWindow\(id: "main"\)/);
assert.doesNotMatch(mac, /private let paper = Color/);
assert.match(browser, /prefers-color-scheme: dark/);
assert.match(browser, /focus-visible/);
assert.match(browser, /prefers-reduced-motion: reduce/);

console.log("PAUSE UI structural audit passed: iPhone, Mac, Screen Time and browser popup.");
