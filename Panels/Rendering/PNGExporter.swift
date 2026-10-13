import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ExportResolution: Int, CaseIterable, Identifiable, Sendable {
    case standard = 300
    case high = 600

    var id: Self { self }
    var label: String { "\(rawValue) DPI" }

    func pixels(for size: PanelSize) -> (width: Int, height: Int) {
        (size.width * rawValue / 25_400, size.height * rawValue / 25_400)
    }
}

enum PNGExporter {
    static func image(_ design: PanelDesign, resolution: ExportResolution) throws -> CGImage {
        try design.validate()
        let pixels = resolution.pixels(for: design.size)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: pixels.width, height: pixels.height,
                bitsPerComponent: 8, bytesPerRow: pixels.width * 4,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { throw PanelError.exportFailed }
        context.translateBy(x: 0, y: Double(pixels.height))
        context.scaleBy(x: 1, y: -1)
        PanelRenderer.draw(design, in: context,
                           size: CGSize(width: pixels.width, height: pixels.height))
        guard let image = context.makeImage() else { throw PanelError.exportFailed }
        return image
    }

    static func data(_ design: PanelDesign, resolution: ExportResolution) throws -> Data {
        let image = try image(design, resolution: resolution)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.png.identifier as CFString, 1, nil
        ) else { throw PanelError.exportFailed }
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: resolution.rawValue,
            kCGImagePropertyDPIHeight: resolution.rawValue,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PanelError.exportFailed }
        return data as Data
    }

    static func write(_ design: PanelDesign, resolution: ExportResolution, to url: URL) throws {
        try data(design, resolution: resolution).write(to: url, options: .atomic)
    }
}
