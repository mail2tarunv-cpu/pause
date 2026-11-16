#!/usr/bin/env node
// Collect the SF Symbol identifiers referenced by native PAUSE UI sources.
// This is source-scoped: it does not infer symbols from arbitrary text strings.
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const names = new Set();

function visit(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) { visit(full); continue; }
    if (!entry.name.endsWith(".swift")) continue;
    const source = fs.readFileSync(full, "utf8");
    for (const line of source.split("\n")) {
      // systemName/systemImage fields can be ternaries containing two names.
      const marker = /\b(systemName|systemImage|symbol):/.exec(line);
      if (!marker) continue;
      const tail = line.slice(marker.index + marker[0].length);
      for (const match of tail.matchAll(/"([a-z][a-z0-9.-]*)"/g)) {
        names.add(match[1]);
      }
    }
    // PAUSECategory and PAUSEMacSection use switch-based computed icon names.
    const iconProperty = /var icon: String\s*\{([\s\S]*?)\n    \}/g;
    for (const block of source.matchAll(iconProperty)) {
      for (const match of block[1].matchAll(/return\s+"([a-z][a-z0-9.-]*)"/g)) {
        names.add(match[1]);
      }
    }
  }
}
visit(path.join(root, "ios"));
visit(path.join(root, "macos"));
const sorted = [...names].sort();
if (sorted.length < 20) {
  console.error("Audit found too few symbols: the source scan may be incomplete.");
  process.exitCode = 1;
} else {
  process.stdout.write(sorted.join("\n") + "\n");
}
