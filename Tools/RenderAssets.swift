import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@main
struct RenderAssets {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let iconDirectory = root.appendingPathComponent("Panels/Assets.xcassets/AppIcon.appiconset")
        try FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
        for pixels in [16, 32, 64, 128, 256, 512, 1024] {
            try drawIcon(pixels: pixels, to: iconDirectory.appendingPathComponent("icon-\(pixels).png"))
        }
        let exampleURL = root.appendingPathComponent("Examples/Serge Prototype.panel")
        var design = try PanelDesign.decode(Data(contentsOf: exampleURL))
        for finish in PanelFinish.allCases {
            design.finish = finish
            let filename = finish == .enamel ? "Serge Prototype.png" : "Serge Prototype \(finish.name).png"
            try PNGExporter.write(design, resolution: .standard,
                                  to: root.appendingPathComponent("Examples/\(filename)"))
        }
    }

    private static func drawIcon(pixels: Int, to url: URL) throws {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixels, height: pixels,
                                      bitsPerComponent: 8, bytesPerRow: pixels * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw PanelError.exportFailed }
        context.translateBy(x: 0, y: Double(pixels))
        context.scaleBy(x: Double(pixels) / 100, y: -Double(pixels) / 100)
        let outline = CGPath(roundedRect: CGRect(x: 4, y: 4, width: 92, height: 92),
                             cornerWidth: 20, cornerHeight: 20, transform: nil)
        context.setFillColor(PanelRenderer.paper)
        context.addPath(outline)
        context.fillPath()
        context.setStrokeColor(PanelRenderer.frameInk)
        context.setLineWidth(0.5)
        context.addPath(outline)
        context.strokePath()
        let controls: [(ControlKind, PanelColor, FramePreset, CGPoint)] = [
            (.pomona1581, .white, .rectangle, CGPoint(x: 32, y: 32)),
            (.pomona1581, .red, .diamond, CGPoint(x: 68, y: 32)),
            (.bourns51, .black, .arch, CGPoint(x: 32, y: 68)),
            (.nkkMN12, .black, .peak, CGPoint(x: 68, y: 68)),
        ]
        for (kind, color, frame, center) in controls {
            PanelRenderer.drawFrame(frame, rotation: .zero, in: context,
                                    rect: CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36))
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.scaleBy(x: 2, y: 2)
            let cell = PanelCell(control: kind, color: color)
            PanelRenderer.drawControl(cell, in: context, center: .zero)
            context.restoreGState()
        }
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil
              ) else { throw PanelError.exportFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PanelError.exportFailed }
    }
}
