import AppKit

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Could not get graphics context")
}

// 1. Background Squircle (Apple standard macOS app icon shape)
let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Shadow for squircle
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -20), blur: 40, color: NSColor.black.withAlphaComponent(0.35).cgColor)
context.addPath(squirclePath)
context.setFillColor(NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0).cgColor)
context.fillPath()
context.restoreGState()

// Clip to squircle for interior gradient
context.saveGState()
context.addPath(squirclePath)
context.clip()

// Base deep gradient
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(red: 0.13, green: 0.20, blue: 0.36, alpha: 1.0).cgColor,
    NSColor(red: 0.07, green: 0.10, blue: 0.19, alpha: 1.0).cgColor
] as CFArray
if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(bgGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
}

// Subtle top lighting glow
let glowColors = [
    NSColor.white.withAlphaComponent(0.12).cgColor,
    NSColor.white.withAlphaComponent(0.0).cgColor
] as CFArray
if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
    context.drawLinearGradient(glowGradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 600), options: [])
}

// 2. Notebook / Syllabus Card Base (White/Cream Page)
let pageRect = CGRect(x: 230, y: 220, width: 564, height: 600)
let pagePath = CGPath(roundedRect: pageRect, cornerWidth: 32, cornerHeight: 32, transform: nil)

// Page Shadow
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor.black.withAlphaComponent(0.4).cgColor)
context.addPath(pagePath)
context.setFillColor(NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0).cgColor)
context.fillPath()
context.restoreGState()

// Subtle inner page border
context.saveGState()
context.addPath(pagePath)
context.setStrokeColor(NSColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1.0).cgColor)
context.setLineWidth(2)
context.strokePath()
context.restoreGState()

// 3. Colored Syllabus Index Tabs on the right edge
let tabs: [(color: NSColor, y: CGFloat)] = [
    (NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0), 680), // Blue
    (NSColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1.0), 570), // Purple
    (NSColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0), 460)  // Emerald
]

for tab in tabs {
    let tabRect = CGRect(x: 774, y: tab.y, width: 34, height: 75)
    let tabPath = CGPath(roundedRect: tabRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
    context.saveGState()
    context.addPath(tabPath)
    context.setFillColor(tab.color.cgColor)
    context.fillPath()
    context.restoreGState()
}

// 4. Checklist Items & Hierarchy Lines on the Syllabus Page
// Header Line
let headerRect = CGRect(x: 290, y: 720, width: 220, height: 28)
let headerPath = CGPath(roundedRect: headerRect, cornerWidth: 7, cornerHeight: 7, transform: nil)
context.addPath(headerPath)
context.setFillColor(NSColor(red: 0.15, green: 0.22, blue: 0.35, alpha: 1.0).cgColor)
context.fillPath()

// Progress Mini Bar under header
let progressBgRect = CGRect(x: 290, y: 680, width: 444, height: 10)
let progressBgPath = CGPath(roundedRect: progressBgRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
context.addPath(progressBgPath)
context.setFillColor(NSColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1.0).cgColor)
context.fillPath()

let progressFillRect = CGRect(x: 290, y: 680, width: 310, height: 10)
let progressFillPath = CGPath(roundedRect: progressFillRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
context.addPath(progressFillPath)
context.setFillColor(NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0).cgColor)
context.fillPath()

// Checklist Row 1: Completed
let check1Rect = CGRect(x: 290, y: 590, width: 36, height: 36)
let check1Path = CGPath(roundedRect: check1Rect, cornerWidth: 9, cornerHeight: 9, transform: nil)
context.addPath(check1Path)
context.setFillColor(NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0).cgColor)
context.fillPath()

// Checkmark symbol
context.saveGState()
context.setStrokeColor(NSColor.white.cgColor)
context.setLineWidth(5)
context.setLineCap(.round)
context.setLineJoin(.round)
context.beginPath()
context.move(to: CGPoint(x: 298, y: 608))
context.addLine(to: CGPoint(x: 305, y: 601))
context.addLine(to: CGPoint(x: 318, y: 616))
context.strokePath()
context.restoreGState()

// Topic 1 Text Lines
let line1Rect = CGRect(x: 345, y: 608, width: 260, height: 14)
context.addPath(CGPath(roundedRect: line1Rect, cornerWidth: 4, cornerHeight: 4, transform: nil))
context.setFillColor(NSColor(red: 0.55, green: 0.60, blue: 0.68, alpha: 1.0).cgColor)
context.fillPath()

let tag1Rect = CGRect(x: 620, y: 604, width: 70, height: 20)
context.addPath(CGPath(roundedRect: tag1Rect, cornerWidth: 5, cornerHeight: 5, transform: nil))
context.setFillColor(NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.18).cgColor)
context.fillPath()

// Checklist Row 2: Subtopic 1 (Completed)
let check2Rect = CGRect(x: 345, y: 535, width: 28, height: 28)
let check2Path = CGPath(roundedRect: check2Rect, cornerWidth: 7, cornerHeight: 7, transform: nil)
context.addPath(check2Path)
context.setFillColor(NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0).cgColor)
context.fillPath()

context.saveGState()
context.setStrokeColor(NSColor.white.cgColor)
context.setLineWidth(4)
context.setLineCap(.round)
context.setLineJoin(.round)
context.beginPath()
context.move(to: CGPoint(x: 351, y: 549))
context.addLine(to: CGPoint(x: 357, y: 543))
context.addLine(to: CGPoint(x: 367, y: 555))
context.strokePath()
context.restoreGState()

let line2Rect = CGRect(x: 390, y: 549, width: 200, height: 12)
context.addPath(CGPath(roundedRect: line2Rect, cornerWidth: 4, cornerHeight: 4, transform: nil))
context.setFillColor(NSColor(red: 0.65, green: 0.70, blue: 0.76, alpha: 1.0).cgColor)
context.fillPath()

// Checklist Row 3: Subtopic 2 (Unchecked)
let check3Rect = CGRect(x: 345, y: 475, width: 28, height: 28)
let check3Path = CGPath(roundedRect: check3Rect, cornerWidth: 7, cornerHeight: 7, transform: nil)
context.addPath(check3Path)
context.setStrokeColor(NSColor(red: 0.75, green: 0.78, blue: 0.85, alpha: 1.0).cgColor)
context.setLineWidth(3)
context.strokePath()

let line3Rect = CGRect(x: 390, y: 489, width: 230, height: 12)
context.addPath(CGPath(roundedRect: line3Rect, cornerWidth: 4, cornerHeight: 4, transform: nil))
context.setFillColor(NSColor(red: 0.25, green: 0.30, blue: 0.40, alpha: 1.0).cgColor)
context.fillPath()

// Checklist Row 4: Top-level Topic 2 (Unchecked)
let check4Rect = CGRect(x: 290, y: 405, width: 36, height: 36)
let check4Path = CGPath(roundedRect: check4Rect, cornerWidth: 9, cornerHeight: 9, transform: nil)
context.addPath(check4Path)
context.setStrokeColor(NSColor(red: 0.70, green: 0.74, blue: 0.82, alpha: 1.0).cgColor)
context.setLineWidth(3.5)
context.strokePath()

let line4Rect = CGRect(x: 345, y: 423, width: 280, height: 14)
context.addPath(CGPath(roundedRect: line4Rect, cornerWidth: 4, cornerHeight: 4, transform: nil))
context.setFillColor(NSColor(red: 0.20, green: 0.26, blue: 0.38, alpha: 1.0).cgColor)
context.fillPath()

let tag4Rect = CGRect(x: 645, y: 420, width: 60, height: 20)
context.addPath(CGPath(roundedRect: tag4Rect, cornerWidth: 5, cornerHeight: 5, transform: nil))
context.setFillColor(NSColor(red: 0.85, green: 0.3, blue: 0.3, alpha: 0.18).cgColor)
context.fillPath()

// Hierarchy guide lines
context.saveGState()
context.setStrokeColor(NSColor(red: 0.80, green: 0.83, blue: 0.89, alpha: 1.0).cgColor)
context.setLineWidth(2)
context.beginPath()
context.move(to: CGPoint(x: 310, y: 585))
context.addLine(to: CGPoint(x: 310, y: 490))
context.addLine(to: CGPoint(x: 338, y: 490))
context.strokePath()
context.restoreGState()

// 5. Bookmark Ribbon at top left of the page
let ribbonPath = CGMutablePath()
ribbonPath.move(to: CGPoint(x: 480, y: 820))
ribbonPath.addLine(to: CGPoint(x: 540, y: 820))
ribbonPath.addLine(to: CGPoint(x: 540, y: 700))
ribbonPath.addLine(to: CGPoint(x: 510, y: 725))
ribbonPath.addLine(to: CGPoint(x: 480, y: 700))
ribbonPath.closeSubpath()

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -6), blur: 10, color: NSColor.black.withAlphaComponent(0.3).cgColor)
context.addPath(ribbonPath)
context.setFillColor(NSColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 1.0).cgColor)
context.fillPath()
context.restoreGState()

context.restoreGState() // Unclip squircle

// Subtle squircle border
context.saveGState()
context.addPath(squirclePath)
context.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
context.setLineWidth(2)
context.strokePath()
context.restoreGState()

image.unlockFocus()

// Export 1024x1024 master PNG
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert image to PNG")
}

let outputPath = "scripts/icon_1024.png"
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Successfully generated \(outputPath)")
