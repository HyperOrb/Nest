import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
NSColor.clear.setFill()
rect.fill()

let tile = NSBezierPath(roundedRect: rect.insetBy(dx: 80, dy: 80), xRadius: 210, yRadius: 210)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.20, green: 0.58, blue: 0.92, alpha: 1),
    NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.62, alpha: 1)
])!
gradient.draw(in: tile, angle: 90)

NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
tile.lineWidth = 10
tile.stroke()

let file = NSBezierPath(roundedRect: NSRect(x: 382, y: 384, width: 260, height: 330), xRadius: 34, yRadius: 34)
NSColor(calibratedWhite: 1, alpha: 0.92).setFill()
file.fill()

let fold = NSBezierPath()
fold.move(to: NSPoint(x: 588, y: 714))
fold.line(to: NSPoint(x: 642, y: 660))
fold.line(to: NSPoint(x: 588, y: 660))
fold.close()
NSColor(calibratedRed: 0.76, green: 0.88, blue: 1.0, alpha: 1).setFill()
fold.fill()

let nest = NSBezierPath()
nest.move(to: NSPoint(x: 250, y: 420))
nest.curve(to: NSPoint(x: 774, y: 420), controlPoint1: NSPoint(x: 352, y: 250), controlPoint2: NSPoint(x: 672, y: 250))
nest.curve(to: NSPoint(x: 250, y: 420), controlPoint1: NSPoint(x: 660, y: 340), controlPoint2: NSPoint(x: 364, y: 340))
nest.close()
NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.24, alpha: 0.92).setFill()
nest.fill()

let inner = NSBezierPath()
inner.move(to: NSPoint(x: 335, y: 425))
inner.curve(to: NSPoint(x: 689, y: 425), controlPoint1: NSPoint(x: 420, y: 355), controlPoint2: NSPoint(x: 604, y: 355))
inner.lineWidth = 30
NSColor(calibratedRed: 0.85, green: 0.94, blue: 1.0, alpha: 0.78).setStroke()
inner.stroke()

for (x, y, w) in [(318.0, 492.0, 210.0), (486.0, 505.0, 220.0), (382.0, 548.0, 270.0)] {
    let twig = NSBezierPath()
    twig.move(to: NSPoint(x: x, y: y))
    twig.curve(to: NSPoint(x: x + w, y: y - 30), controlPoint1: NSPoint(x: x + 75, y: y + 34), controlPoint2: NSPoint(x: x + w - 80, y: y - 62))
    twig.lineWidth = 26
    twig.lineCapStyle = .round
    NSColor(calibratedWhite: 1, alpha: 0.82).setStroke()
    twig.stroke()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}

try png.write(to: URL(fileURLWithPath: "AppIcon-1024.png"))
