const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.join(__dirname, "..");
const load = p => fs.readFileSync(path.join(root, p), "utf8");

function luminance(hex) {
  const channels = hex.replace("#", "").match(/.{2}/g).map(c => parseInt(c,16)/255);
  const linear = channels.map(v => v <= .04045 ? v/12.92 : ((v + .055)/1.055)**2.4);
  return .2126*linear[0] + .7152*linear[1] + .0722*linear[2];
}
function contrast(a,b) {
  const [light,dark] = [luminance(a),luminance(b)].sort((x,y)=>y-x);
  return (light+.05)/(dark+.05);
}
for(const [label,bg,fg] of [
  ["light primary", "#1d1e20", "#f7f6f2"],
  ["light primary hover", "#34373a", "#f7f6f2"],
  ["light secondary", "#fdfdfb", "#171819"],
  ["light secondary hover", "#f0f1ee", "#171819"],
  ["light input", "#ffffff", "#191a1b"],
  ["light helper", "#f7f7f5", "#555954"],
  ["dark primary", "#ededeb", "#171819"],
  ["dark secondary", "#343639", "#f5f5f2"],
  ["dark secondary hover", "#424548", "#f5f5f2"],
  ["dark input", "#2a2c2f", "#faf9f6"],
  ["dark helper", "#151516", "#c4c6c1"],
  ["extension light primary", "#08796d", "#ffffff"],
  ["extension dark primary", "#75e3d2", "#111514"],
  ["board glyph", "#242627", "#f3f2ef"]
]) {
  const ratio = contrast(bg,fg);
  assert.ok(ratio >= 4.5, label + " fails WCAG AA: " + ratio.toFixed(2));
}

const css = load("design/contrast-fixes.css");
for(const declaration of [
  "--ui-primary-bg", "--ui-primary-fg", "--ui-secondary-bg",
  "--ui-secondary-fg", "--ui-primary-hover-bg", "--ui-field-fg",
  "--ui-focus", "--ui-disabled-bg"
]) assert.ok(css.includes(declaration), "Missing contrast token: " + declaration);
assert.match(css, /body button/);
assert.match(css, /body \.preset/);
assert.match(css, /button\.primary/);
assert.match(css, /:disabled/);
assert.match(css, /prefers-color-scheme: dark/);
assert.match(css, /\.flap-grid \.tile \.printed-glyph/);
assert.match(css, /\.flap-grid \.tile \.seam/);
assert.match(css, /body\.pause-board-page/);
assert.match(css, /transform: none !important/);
for(const html of ["index.html","controller.html","cloud.html"]) {
  const source=load(html);
  const hardware=source.indexOf('design/board-hardware.css');
  const theme=source.indexOf('design/contrast-fixes.css');
  assert.ok(hardware >= 0 && theme > hardware,
    html + " must load contrast CSS after hardware CSS");
}
assert.match(load("relay.py"), /"\/design\/contrast-fixes\.css"/);
assert.ok(!load("ios/App/PAUSEBoardView.swift").includes(".foregroundStyle(.white.opacity(0.65))"),
 "Board preview label must not be white on a white card");
assert.match(load("ios/App/PAUSEBoardView.swift"), /cellWidth \* 0\.74/);
assert.match(load("macos/App/MacDashboard.swift"), /cellWidth \* 0\.74/);
const extension = load("browser-extension/popup.css");
assert.match(extension, /background: #08796d; color: #ffffff/);
assert.match(extension, /background: #75e3d2; color: #111514/);
console.log("PAUSE web, native board and extension contrast checks passed (all assessed pairs >= 4.5:1).");
