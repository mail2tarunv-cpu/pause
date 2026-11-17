const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.join(__dirname, "..");
const load = name => fs.readFileSync(path.join(root, name), "utf8");

const script = load("scripts/prepare_fonts.sh");
for (const font of [
  "SpaceGrotesk-Regular.ttf", "SpaceGrotesk-Medium.ttf",
  "SpaceGrotesk-Bold.ttf", "DMMono-Regular.ttf", "DMMono-Medium.ttf"
]) {
  assert.ok(script.includes(font), font + " must be prepared");
  for (const project of ["ios/project.yml", "macos/project.yml"]) {
    assert.ok(load(project).includes("../assets/fonts/" + font),
      project + " must package " + font);
  }
}
assert.match(script, /OFL-/);

for (const name of ["index.html", "controller.html", "cloud.html"]) {
  const html = load(name);
  assert.ok(html.includes("design/pause-theme.css"), name + " missing shared theme");
  assert.ok(html.includes("Space+Grotesk"), name + " missing heading font");
  assert.ok(html.includes("DM+Mono"), name + " missing body font");
  if(name==="index.html") {
    assert.ok(html.includes("design/board-hardware.css"),
      "The standalone board must use the hardware-first display stylesheet.");
  } else {
    assert.ok(html.includes("pause-shape-strip"),
      name + " missing supporting shapes");
  }
}
const tokens = load("design/pause-theme.css");
for (const token of [
  "--pause-orange", "--pause-yellow", "--pause-pink",
  "--pause-cyan", "--pause-violet", "--pause-lime",
  "--pause-heading", "--pause-body"
]) {
  assert.ok(tokens.includes(token), "Missing design token " + token);
}
assert.match(tokens, /prefers-color-scheme: dark/);
assert.match(tokens, /prefers-reduced-motion: reduce/);
assert.match(tokens, /\.tile \.glyph/);

const iosTheme = load("ios/App/PAUSETheme.swift");
assert.match(iosTheme, /systemGroupedBackground/);
assert.match(iosTheme, /\.system\(style, design: \.default/);
assert.doesNotMatch(iosTheme, /PAUSEShapeStamp|SpaceGrotesk-Bold|DMMono-Regular/);
assert.match(load("ios/App/Info.plist"), /UIAppFonts/);
assert.match(load("ios/Report/Info.plist"), /UIAppFonts/);
assert.match(load("ios/Report/PAUSEReportExtension.swift"), /\.system\(style, design: \.default/);
assert.match(load("ios/App/PAUSEBoardView.swift"), /"DMMono-Medium"/);
assert.match(load("macos/App/PAUSEStyle.swift"), /CTFontManagerRegisterFontsForURL/);
assert.match(load("macos/App/MacDashboard.swift"), /PAUSEMacPanel/);
assert.match(load("macos/App/MacDashboard.swift"), /"DMMono-Medium"/);
assert.match(load("macos/App/PAUSEStyle.swift"), /\.system\(style, design: \.default/);
assert.match(load("macos/App/PAUSEMacApp.swift"), /PAUSEMacFonts.register\(\)/);

const extensionCSS = load("browser-extension/popup.css");
assert.match(extensionCSS, /@font-face/);
assert.match(extensionCSS, /fonts\/DMMono-Regular\.ttf/);
assert.match(extensionCSS, /fonts\/SpaceGrotesk-Bold\.ttf/);

const relay = load("relay.py");
assert.match(relay, /"\/design\/pause-theme\.css"/);
assert.match(relay, /"text\/css; charset=utf-8"/);
console.log("PAUSE brand integration passed: editorial web, native SF interfaces, custom board glyphs, and licensed bundled fonts.");
