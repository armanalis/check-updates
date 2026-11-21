// Draws the app icon and writes AppIcon.icns. Run: ./make_icon.sh
import AppKit

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// macOS icon grid: 824pt rounded square centered on a 1024 canvas
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let path = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSShadow().apply { $0.shadowBlurRadius = 20; $0.shadowOffset = NSSize(width: 0, height: -10); $0.shadowColor = .black.withAlphaComponent(0.3) }
NSGradient(starting: NSColor(red: 0.20, green: 0.80, blue: 0.45, alpha: 1),
           ending: NSColor(red: 0.05, green: 0.50, blue: 0.35, alpha: 1))!.draw(in: path, angle: -90)

let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
    .applying(.init(paletteColors: [NSColor(red: 0.05, green: 0.50, blue: 0.35, alpha: 1), .white]))
let symbol = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)!
    .withSymbolConfiguration(config)!
let s = symbol.size
symbol.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))

img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

extension NSShadow { func apply(_ f: (NSShadow) -> Void) { f(self); set() } }
