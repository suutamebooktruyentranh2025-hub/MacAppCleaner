#!/usr/bin/env swift
import Cocoa
import CoreGraphics

func createMasterIcon() -> NSImage {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    // Clear canvas
    context.clear(CGRect(origin: .zero, size: size))
    
    // Icon squircle bounding box (macOS standard: 824x824 centered inside 1024x1024)
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // 1. Drop shadow for the squircle
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -20), blur: 36, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.40))
    context.addPath(squirclePath)
    context.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1.0))
    context.fillPath()
    context.restoreGState()
    
    // 2. Base Background Gradient (Deep Sapphire -> Electric Indigo -> Vibrant Cyan)
    context.saveGState()
    context.addPath(squirclePath)
    context.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 1.0), // Deep midnight blue
        CGColor(red: 0.12, green: 0.24, blue: 0.58, alpha: 1.0), // Royal sapphire
        CGColor(red: 0.15, green: 0.45, blue: 0.82, alpha: 1.0), // Vibrant cobalt
        CGColor(red: 0.05, green: 0.65, blue: 0.85, alpha: 1.0)  // Luminous cyan
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.35, 0.70, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        context.drawLinearGradient(
            bgGradient,
            start: CGPoint(x: 512, y: 924),
            end: CGPoint(x: 512, y: 100),
            options: []
        )
    }
    
    // 3. Subtle inner glow & diagonal sheen
    let sheenColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
    ] as CFArray
    if let sheenGradient = CGGradient(colorsSpace: colorSpace, colors: sheenColors, locations: [0.0, 0.4, 1.0]) {
        context.drawLinearGradient(
            sheenGradient,
            start: CGPoint(x: 200, y: 900),
            end: CGPoint(x: 700, y: 400),
            options: []
        )
    }
    
    // 4. Central Motif: Stylized Modern Disk Drive / Mac Window + Magic Cleaner Sparks
    // Outer floating rounded card (frosted plate)
    let plateRect = CGRect(x: 232, y: 232, width: 560, height: 560)
    let plateRadius: CGFloat = 110
    let platePath = CGPath(roundedRect: plateRect, cornerWidth: plateRadius, cornerHeight: plateRadius, transform: nil)
    
    // Plate shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    context.addPath(platePath)
    context.setFillColor(CGColor(red: 0.04, green: 0.08, blue: 0.18, alpha: 0.75))
    context.fillPath()
    context.restoreGState()
    
    // Plate gradient fill
    context.saveGState()
    context.addPath(platePath)
    context.clip()
    let plateColors = [
        CGColor(red: 0.10, green: 0.18, blue: 0.36, alpha: 0.85),
        CGColor(red: 0.06, green: 0.10, blue: 0.22, alpha: 0.92)
    ] as CFArray
    if let plateGrad = CGGradient(colorsSpace: colorSpace, colors: plateColors, locations: [0.0, 1.0]) {
        context.drawLinearGradient(plateGrad, start: CGPoint(x: 512, y: 792), end: CGPoint(x: 512, y: 232), options: [])
    }
    
    // Plate inner border
    context.setStrokeColor(CGColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.35))
    context.setLineWidth(3)
    context.addPath(platePath)
    context.strokePath()
    context.restoreGState()
    
    // 5. Stylized Hard Drive / Clean Ring Motif
    let center = CGPoint(x: 512, y: 512)
    
    // Concentric clean storage arc rings
    context.saveGState()
    context.setLineWidth(14)
    context.setLineCap(.round)
    
    // Outer cyan ring
    context.setStrokeColor(CGColor(red: 0.15, green: 0.85, blue: 0.95, alpha: 0.85))
    context.addArc(center: center, radius: 180, startAngle: .pi * 0.2, endAngle: .pi * 1.8, clockwise: false)
    context.strokePath()
    
    // Inner emerald / mint ring (symbolizing green clean storage)
    context.setStrokeColor(CGColor(red: 0.2, green: 0.95, blue: 0.65, alpha: 0.90))
    context.addArc(center: center, radius: 130, startAngle: .pi * 0.7, endAngle: .pi * 2.3, clockwise: false)
    context.strokePath()
    
    // Center glowing core
    let coreColors = [
        CGColor(red: 0.3, green: 0.95, blue: 0.95, alpha: 0.9),
        CGColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 0.2),
        CGColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 0.0)
    ] as CFArray
    if let coreGrad = CGGradient(colorsSpace: colorSpace, colors: coreColors, locations: [0.0, 0.4, 1.0]) {
        context.drawRadialGradient(
            coreGrad,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: 90,
            options: []
        )
    }
    context.restoreGState()
    
    // 6. Vector Sparkles (Magic Cleaning Sparkles)
    func drawSparkle(at pt: CGPoint, size: CGFloat, color: CGColor) {
        context.saveGState()
        context.setFillColor(color)
        context.setShadow(offset: .zero, blur: 16, color: color)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: pt.x, y: pt.y + size))
        path.addQuadCurve(to: CGPoint(x: pt.x + size * 0.28, y: pt.y), control: CGPoint(x: pt.x + size * 0.05, y: pt.y + size * 0.05))
        path.addQuadCurve(to: CGPoint(x: pt.x, y: pt.y - size), control: CGPoint(x: pt.x + size * 0.05, y: pt.y - size * 0.05))
        path.addQuadCurve(to: CGPoint(x: pt.x - size * 0.28, y: pt.y), control: CGPoint(x: pt.x - size * 0.05, y: pt.y - size * 0.05))
        path.addQuadCurve(to: CGPoint(x: pt.x, y: pt.y + size), control: CGPoint(x: pt.x - size * 0.05, y: pt.y + size * 0.05))
        path.closeSubpath()
        
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }
    
    let sparkleColorWhite = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
    let sparkleColorCyan = CGColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 0.9)
    let sparkleColorGold = CGColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.95)
    
    // Big sparkle at top-right
    drawSparkle(at: CGPoint(x: 670, y: 670), size: 75, color: sparkleColorWhite)
    drawSparkle(at: CGPoint(x: 670, y: 670), size: 50, color: sparkleColorCyan)
    
    // Medium sparkle at bottom-left
    drawSparkle(at: CGPoint(x: 350, y: 350), size: 55, color: sparkleColorGold)
    
    // Small sparkle at top-left
    drawSparkle(at: CGPoint(x: 380, y: 650), size: 36, color: sparkleColorWhite)
    
    // Accent sparkle near center-right
    drawSparkle(at: CGPoint(x: 640, y: 430), size: 28, color: sparkleColorCyan)
    
    // 7. Subtle rim stroke around the main squircle (Apple standard 1.5pt white border at ~25% alpha)
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22))
    context.setLineWidth(3)
    context.addPath(squirclePath)
    context.strokePath()
    
    context.restoreGState() // restores main squircle clip
    
    image.unlockFocus()
    return image
}

let fileManager = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let resourcesURL = rootURL.appendingPathComponent("Sources/MacAppCleaner/Resources")
let iconsetURL = rootURL.appendingPathComponent("build/MacAppCleaner.iconset")
let icnsOutputURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try? fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
try? fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let masterImage = createMasterIcon()

// Define all standard macOS iconset sizes
let iconSizes: [(name: String, pixelSize: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in iconSizes {
    let targetSize = NSSize(width: item.pixelSize, height: item.pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: item.pixelSize,
        pixelsHigh: item.pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = targetSize
    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    masterImage.draw(
        in: NSRect(origin: .zero, size: targetSize),
        from: NSRect(origin: .zero, size: masterImage.size),
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()
    
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Failed to get PNG data for \(item.name)")
        continue
    }
    
    let destURL = iconsetURL.appendingPathComponent(item.name)
    try? pngData.write(to: destURL)
}

// Also write a 512x512 PNG directly to resources for in-app display (e.g. Sidebar Header / About)
let appIconPngURL = resourcesURL.appendingPathComponent("AppIcon.png")
if let rep512 = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 512,
    pixelsHigh: 512,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) {
    rep512.size = NSSize(width: 512, height: 512)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep512)
    masterImage.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512), from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep512.representation(using: .png, properties: [:]) {
        try? data.write(to: appIconPngURL)
    }
}

print("Running iconutil to generate AppIcon.icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsOutputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("Successfully generated AppIcon.icns at: \(icnsOutputURL.path)")
} else {
    print("iconutil failed with code: \(process.terminationStatus)")
    exit(1)
}
