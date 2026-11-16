import AppKit
import CoreGraphics
import Foundation

// Original PAUSE app icon: two vertical columns of three split-flap tiles.
// The restrained mark resembles a pause symbol at small sizes and a physical
// flipboard when enlarged. No third-party imagery or SF Symbol art is embedded.
let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: 1)
}

func rounded(_ context: CGContext, _ rect: CGRect, radius: CGFloat, fill: CGColor) {
    context.addPath(CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    ))
    context.setFillColor(fill)
    context.fillPath()
}

func drawIcon(_ side: Int) throws -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil, width: side, height: side,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "PAUSEIcon", code: 1)
    }

    // All design units use a 1024 × 1024 canvas.
    let scale = CGFloat(side) / 1024
    context.scaleBy(x: scale, y: scale)
    context.setFillColor(color(0.075, 0.19, 0.20))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    // Two tile columns suggest the pause mark. Splits provide the physical
    // Vestaboard character without adding illegible letters or decoration.
    let cream = color(0.960, 0.955, 0.926)
    let lower = color(0.850, 0.873, 0.846)
    let seam = color(0.54, 0.62, 0.60)
    for x in [307.0, 563.0] {
        for y in [240.0, 416.0, 592.0] {
            let tile = CGRect(x: x, y: y, width: 154, height: 162)
            rounded(context, tile, radius: 14, fill: cream)
            context.saveGState()
            context.addPath(CGPath(
                roundedRect: tile, cornerWidth: 14,
                cornerHeight: 14, transform: nil
            ))
            context.clip()
            context.setFillColor(lower)
            context.fill(CGRect(x: x, y: y, width: 154, height: 80))
            context.setFillColor(seam)
            context.fill(CGRect(x: x, y: y + 79, width: 154, height: 3))
            context.restoreGState()
        }
    }

    guard let image = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: image).representation(
              using: .png, properties: [:]
          ) else {
        throw NSError(domain: "PAUSEIcon", code: 2)
    }
    return png
}

func write(_ path: String, side: Int) throws {
    let file = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try drawIcon(side).write(to: file, options: .atomic)
    print("Generated \(path) (\(side) px)")
}

try write("ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png", side: 1024)
for (base, scale) in [(16,1),(16,2),(32,1),(32,2),
                      (128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    try write(
        "macos/App/Assets.xcassets/AppIcon.appiconset/mac-\(base)-\(scale)x.png",
        side: base * scale
    )
}
try write("browser-extension/icon48.png", side: 48)
try write("browser-extension/icon128.png", side: 128)
