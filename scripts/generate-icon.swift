#!/usr/bin/env swift
// Draws Transflo's app icon (a radial wheel with one highlighted wedge around a file) and writes
// every macOS AppIcon size plus Contents.json, or the iPhone/iPad icon and launch logo.
// Usage: swift scripts/generate-icon.swift TransfloForMac/Resources/Assets.xcassets/AppIcon.appiconset
//        swift scripts/generate-icon.swift --ios TransfloMobile/Resources/Assets.xcassets
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Brand values mirrored from the asset catalog (ink + teal).
enum IconPalette {
    static let inkTop = rgb(0x24282B)
    static let inkBottom = rgb(0x141618)
    static let wedge = rgb(0x30353A)
    static let accent = rgb(0x3FB8A5)
    static let paper = rgb(0xF6F4EF)
    static let fold = rgb(0xCFCBC2)

    static func rgb(_ hex: Int) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Geometry for the 1024 pt full-size render, following the macOS icon grid (824 pt tile, 100 pt margin).
enum IconGeometry {
    static let canvas: CGFloat = 1024
    static let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    static let tileRadius: CGFloat = 185
    static let center = CGPoint(x: 512, y: 512)
    static let outerRadius: CGFloat = 300
    static let innerRadius: CGFloat = 158
    static let wedgeCount = 6
    static let gapDegrees: CGFloat = 7
    static let highlightedWedge = 1
}

func makeContext(size: Int, opaque: Bool = false) -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue
    ) else {
        fatalError("Could not create a \(size)px bitmap context")
    }
    return context
}

func drawTile(in context: CGContext) {
    let path = CGPath(
        roundedRect: IconGeometry.tile,
        cornerWidth: IconGeometry.tileRadius,
        cornerHeight: IconGeometry.tileRadius,
        transform: nil
    )
    context.saveGState()
    context.addPath(path)
    context.clip()
    let colors = [IconPalette.inkTop, IconPalette.inkBottom] as CFArray
    if let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 512, y: IconGeometry.tile.maxY),
            end: CGPoint(x: 512, y: IconGeometry.tile.minY),
            options: []
        )
    }
    context.restoreGState()
}

func drawWheel(in context: CGContext) {
    let step = 360 / CGFloat(IconGeometry.wedgeCount)
    let gap = IconGeometry.gapDegrees
    for index in 0..<IconGeometry.wedgeCount {
        // Start at 12 o'clock and go clockwise.
        let start = (90 - CGFloat(index) * step - gap / 2) * .pi / 180
        let end = (90 - CGFloat(index + 1) * step + gap / 2) * .pi / 180
        let path = CGMutablePath()
        path.addArc(center: IconGeometry.center, radius: IconGeometry.outerRadius,
                    startAngle: start, endAngle: end, clockwise: true)
        path.addArc(center: IconGeometry.center, radius: IconGeometry.innerRadius,
                    startAngle: end, endAngle: start, clockwise: false)
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(index == IconGeometry.highlightedWedge ? IconPalette.accent : IconPalette.wedge)
        context.fillPath()
    }
}

func drawFile(in context: CGContext) {
    let width: CGFloat = 132
    let height: CGFloat = 168
    let fold: CGFloat = 42
    let origin = CGPoint(x: IconGeometry.center.x - width / 2, y: IconGeometry.center.y - height / 2)

    let sheet = CGMutablePath()
    sheet.move(to: origin)
    sheet.addLine(to: CGPoint(x: origin.x + width, y: origin.y))
    sheet.addLine(to: CGPoint(x: origin.x + width, y: origin.y + height - fold))
    sheet.addLine(to: CGPoint(x: origin.x + width - fold, y: origin.y + height))
    sheet.addLine(to: CGPoint(x: origin.x, y: origin.y + height))
    sheet.closeSubpath()
    context.addPath(sheet)
    context.setFillColor(IconPalette.paper)
    context.fillPath()

    let corner = CGMutablePath()
    corner.move(to: CGPoint(x: origin.x + width - fold, y: origin.y + height))
    corner.addLine(to: CGPoint(x: origin.x + width - fold, y: origin.y + height - fold))
    corner.addLine(to: CGPoint(x: origin.x + width, y: origin.y + height - fold))
    corner.closeSubpath()
    context.addPath(corner)
    context.setFillColor(IconPalette.fold)
    context.fillPath()
}

func renderFullSize() -> CGImage {
    let context = makeContext(size: Int(IconGeometry.canvas))
    drawTile(in: context)
    drawWheel(in: context)
    drawFile(in: context)
    guard let image = context.makeImage() else { fatalError("Could not render the full-size icon") }
    return image
}

func resized(_ image: CGImage, to size: Int) -> CGImage {
    let context = makeContext(size: size)
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let output = context.makeImage() else { fatalError("Could not resize to \(size)px") }
    return output
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        fatalError("Could not create \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write \(url.path)") }
}

/// iOS masks the icon itself, so the ink fills the whole opaque square and the artwork grows to
/// match the Mac tile's proportions.
func renderIOSIcon() -> CGImage {
    let context = makeContext(size: Int(IconGeometry.canvas), opaque: true)
    let colors = [IconPalette.inkTop, IconPalette.inkBottom] as CFArray
    if let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1]) {
        context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: [])
    }
    drawArtwork(in: context, scale: IconGeometry.canvas / IconGeometry.tile.width)
    guard let image = context.makeImage() else { fatalError("Could not render the iOS icon") }
    return image
}

/// The wheel and file on transparency, for the launch screen.
func renderLaunchLogo(size: Int) -> CGImage {
    let context = makeContext(size: size)
    context.scaleBy(x: CGFloat(size) / IconGeometry.canvas, y: CGFloat(size) / IconGeometry.canvas)
    drawArtwork(in: context, scale: 1.4)
    guard let image = context.makeImage() else { fatalError("Could not render the launch logo") }
    return image
}

func drawArtwork(in context: CGContext, scale: CGFloat) {
    context.saveGState()
    context.translateBy(x: IconGeometry.center.x, y: IconGeometry.center.y)
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -IconGeometry.center.x, y: -IconGeometry.center.y)
    drawWheel(in: context)
    drawFile(in: context)
    context.restoreGState()
}

func writeContents(_ contents: [String: Any], to folder: URL) throws {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try json.write(to: folder.appendingPathComponent("Contents.json"))
}

let arguments = CommandLine.arguments
if arguments.count == 3, arguments[1] == "--ios" {
    let catalog = URL(fileURLWithPath: arguments[2], isDirectory: true)
    let icon = catalog.appendingPathComponent("MobileIcon.appiconset", isDirectory: true)
    try writeContents(["images": [["idiom": "universal", "platform": "ios", "size": "1024x1024",
                                   "filename": "icon-1024.png"]],
                       "info": ["author": "xcode", "version": 1]], to: icon)
    writePNG(renderIOSIcon(), to: icon.appendingPathComponent("icon-1024.png"))
    let logo = catalog.appendingPathComponent("LaunchLogo.imageset", isDirectory: true)
    try FileManager.default.createDirectory(at: logo, withIntermediateDirectories: true)
    var images: [[String: String]] = []
    for scale in 1...3 {
        let filename = "launch-logo@\(scale)x.png"
        writePNG(renderLaunchLogo(size: 160 * scale), to: logo.appendingPathComponent(filename))
        images.append(["idiom": "universal", "scale": "\(scale)x", "filename": filename])
    }
    try writeContents(["images": images, "info": ["author": "xcode", "version": 1]], to: logo)
    print("Wrote the iOS icon and launch logo to \(catalog.path)")
    exit(0)
}
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-icon.swift <AppIcon.appiconset>\n".utf8))
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let fullSize = renderFullSize()
var entries: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let filename = "icon_\(points)x\(points)@\(scale)x.png"
        writePNG(resized(fullSize, to: pixels), to: outputDirectory.appendingPathComponent(filename))
        entries.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}
let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDirectory.appendingPathComponent("Contents.json"))
print("Wrote \(entries.count) icon sizes to \(outputDirectory.path)")
