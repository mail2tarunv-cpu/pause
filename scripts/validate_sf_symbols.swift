import AppKit
import Foundation

// Validate all detected identifiers against the installed Apple symbol set.
// Run on a macOS runner (and manually confirm appearance on the minimum iOS).
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift scripts/validate_sf_symbols.swift symbols.txt\n", stderr)
    exit(2)
}
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let contents = try String(contentsOf: source, encoding: .utf8)
let names = contents.split(whereSeparator: \.isNewline).map(String.init)

var failures: [String] = []
for name in names {
    if NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil {
        failures.append(name)
    }
}
if !failures.isEmpty {
    fputs("Missing Apple SF Symbols on this macOS SDK/runtime:\n", stderr)
    for name in failures {
        fputs("  - \(name)\n", stderr)
    }
    exit(1)
}
print("Validated \(names.count) actual SF Symbol identifiers with AppKit.")
