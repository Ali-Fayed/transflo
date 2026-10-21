import AppKit
import CoreImage
import Foundation
import ImageIO

// Synthetic, deterministic source images. No personal photos or working files enter the test bundle.
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    fatalError("Cannot allocate fixture pixels")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 256, height: 256).fill()
NSColor.systemTeal.setFill()
NSRect(x: 0, y: 0, width: 128, height: 180).fill()
NSColor.systemOrange.setFill()
NSRect(x: 128, y: 0, width: 128, height: 180).fill()
("TRANSFLO 2026" as NSString).draw(at: NSPoint(x: 12, y: 210), withAttributes: [
    .font: NSFont.systemFont(ofSize: 25, weight: .bold), .foregroundColor: NSColor.black
])
NSGraphicsContext.restoreGraphicsState()
guard let image = bitmap.cgImage else { fatalError("No fixture pixels") }
let types = ["jpg": "public.jpeg", "png": "public.png", "heic": "public.heic",
             "tiff": "public.tiff", "bmp": "com.microsoft.bmp", "gif": "com.compuserve.gif",
             "avif": "public.avif", "ico": "com.microsoft.ico", "icns": "com.apple.icns"]
for (format, type) in types.sorted(by: { $0.key < $1.key }) {
    let url = destination.appendingPathComponent("source.\(format)")
    guard let writer = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else {
        fatalError("No fixture writer for \(format)")
    }
    CGImageDestinationAddImage(writer, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
    guard CGImageDestinationFinalize(writer) else { fatalError("Fixture encoding failed: \(format)") }
    print("Wrote \(url.lastPathComponent)")
}
let pdfURL = destination.appendingPathComponent("source.pdf")
guard let consumer = CGDataConsumer(url: pdfURL as CFURL) else { fatalError("No PDF consumer") }
var bounds = CGRect(x: 0, y: 0, width: 256, height: 256)
guard let pdf = CGContext(consumer: consumer, mediaBox: &bounds, nil) else { fatalError("No PDF context") }
for page in 1...3 {
    pdf.beginPDFPage(nil)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: pdf, flipped: false)
    ("TRANSFLO Page \(page)" as NSString).draw(at: NSPoint(x: 15, y: 150), withAttributes: [
        .font: NSFont.systemFont(ofSize: 22), .foregroundColor: NSColor.black
    ])
    NSGraphicsContext.restoreGraphicsState()
    pdf.endPDFPage()
}
pdf.closePDF()
// Quiet-zone QR fixtures make the barcode case a positive detection, not an empty-image test.
guard let filter = CIFilter(name: "CIQRCodeGenerator") else { fatalError("No QR filter") }
filter.setValue(Data("https://transflo.example/qa".utf8), forKey: "inputMessage")
guard let code = filter.outputImage else { fatalError("No QR pixels") }
let padded = code.composited(over: CIImage(color: .white).cropped(to: CGRect(x: -16, y: -16, width: 64, height: 64)))
let enlarged = padded.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
guard let qrImage = CIContext().createCGImage(enlarged, from: enlarged.extent) else { fatalError("Cannot render QR") }
for (format, type) in types where !["ico", "icns"].contains(format) {
    let url = destination.appendingPathComponent("qr.\(format)")
    guard let writer = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else {
        fatalError("No QR encoder for \(format)")
    }
    CGImageDestinationAddImage(writer, qrImage, nil)
    guard CGImageDestinationFinalize(writer) else { fatalError("QR encoding failed: \(format)") }
}
let qrURL = destination.appendingPathComponent("qr.pdf")
guard let qrConsumer = CGDataConsumer(url: qrURL as CFURL),
      let qrPDF = CGContext(consumer: qrConsumer, mediaBox: &bounds, nil) else { fatalError("No QR PDF") }
qrPDF.beginPDFPage(nil)
qrPDF.draw(qrImage, in: bounds)
qrPDF.endPDFPage()
qrPDF.closePDF()
