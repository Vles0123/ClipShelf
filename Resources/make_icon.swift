import AppKit
let destination = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 952, height: 952), xRadius: 215, yRadius: 215)
NSGradient(starting: NSColor(calibratedRed: 0.21, green: 0.19, blue: 0.34, alpha: 1), ending: NSColor(calibratedRed: 0.075, green: 0.09, blue: 0.13, alpha: 1))!.draw(in: background, angle: -70)
let back = NSBezierPath(roundedRect: NSRect(x: 258, y: 220, width: 452, height: 564), xRadius: 63, yRadius: 63)
NSColor(calibratedRed: 0.49, green: 0.43, blue: 0.77, alpha: 1).setFill()
back.fill()
let front = NSBezierPath(roundedRect: NSRect(x: 323, y: 170, width: 452, height: 564), xRadius: 63, yRadius: 63)
NSGradient(starting: NSColor(calibratedRed: 0.79, green: 0.74, blue: 1, alpha: 1), ending: NSColor(calibratedRed: 0.61, green: 0.54, blue: 0.9, alpha: 1))!.draw(in: front, angle: -90)
let tab = NSBezierPath(roundedRect: NSRect(x: 438, y: 678, width: 220, height: 102), xRadius: 38, yRadius: 38)
NSColor(calibratedRed: 0.9, green: 0.87, blue: 1, alpha: 1).setFill()
tab.fill()
NSColor(calibratedRed: 0.25, green: 0.22, blue: 0.4, alpha: 0.8).setFill()
for (y, width) in [(540.0, 265.0), (439.0, 265.0), (338.0, 165.0)] {
    NSBezierPath(roundedRect: NSRect(x: 416, y: y, width: width, height: 32), xRadius: 16, yRadius: 16).fill()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
