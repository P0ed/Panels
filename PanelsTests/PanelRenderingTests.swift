import CoreGraphics
import CoreText
import ImageIO
import XCTest
@testable import Panels

final class PanelRenderingTests: XCTestCase {
    func testPanelLetteringUsesBundledFuturaMedium() throws {
        XCTAssertNotNil(PanelTypography.fontData)
        let font = PanelTypography.font(size: 12)
        XCTAssertEqual(CTFontCopyFullName(font) as String, "Futura Medium")
    }

    func testEachPanelFinishChangesPNGArtwork() throws {
        var artworks: Set<Data> = []
        for finish in PanelFinish.allCases {
            var design = PanelDesign(title: "", finish: finish)
            let address = CellAddress(row: 0, column: 0)
            design[address].setControl(.pomona1581)
            design[address].frame = .diamond
            design[address].caption = "IN"
            artworks.insert(try PNGExporter.data(design, resolution: .standard))
        }
        XCTAssertEqual(artworks.count, PanelFinish.allCases.count)
    }

    func testBothSizesHaveCorrectPixelsAndDPIMetadata() throws {
        for size in PanelSize.allCases {
            var design = PanelDesign()
            design.size = size
            let data = try PNGExporter.data(design, resolution: .standard)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(image.width, size == .fourBySix ? 1_275 : 2_550)
            XCTAssertEqual(image.height, 2_100)
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
            XCTAssertEqual(try XCTUnwrap(properties[kCGImagePropertyDPIWidth as String] as? Double), 300, accuracy: 0.1)
            XCTAssertEqual(try XCTUnwrap(properties[kCGImagePropertyDPIHeight as String] as? Double), 300, accuracy: 0.1)
            XCTAssertNotEqual(properties[kCGImagePropertyHasAlpha as String] as? Bool, true)
        }
        let image = try PNGExporter.image(PanelDesign(size: .eightBySix), resolution: .high)
        XCTAssertEqual(image.width, 5_100)
        XCTAssertEqual(image.height, 4_200)
    }

    func testAllControlSymbolsProduceDistinctArtwork() throws {
        var artworks: [Data] = []
        for control in ControlKind.allCases {
            var design = PanelDesign()
            design.title = ""
            design[CellAddress(row: 0, column: 0)].setControl(control)
            artworks.append(try PNGExporter.data(design, resolution: .standard))
        }
        XCTAssertEqual(Set(artworks).count, ControlKind.allCases.count)
    }

    func testAllFramesAndRotationsRenderWithLongCaptions() throws {
        var design = PanelDesign(size: .eightBySix,
                                 title: "A LONG MODULE TITLE WITH MULTIPLE WORDS · ÉTAGE Ω")
        for (index, address) in design.geometry.addresses.enumerated() {
            design[address].setControl(ControlKind.allCases[index % ControlKind.allCases.count])
            design[address].frame = FramePreset.allCases[index % 5]
            design[address].frameRotation = QuarterTurn.allCases[index % 4]
            design[address].caption = index.isMultiple(of: 2) ? "SAMPLE\n& HOLD" : "VERY LONG CONTROL NAME Ω ±"
        }
        let data = try PNGExporter.data(design, resolution: .standard)
        XCTAssertFalse(data.isEmpty)
        let directory = URL(fileURLWithPath: "/tmp/PanelsArtifacts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("frame-and-label-check.png"), options: .atomic)
    }

    func testPreviewAndExportUseTheSameArtwork() throws {
        let design = try exampleDesign()
        let exported = try PNGExporter.image(design, resolution: .standard)
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let preview = try XCTUnwrap(CGContext(
            data: nil, width: exported.width, height: exported.height,
            bitsPerComponent: 8, bytesPerRow: exported.width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        preview.translateBy(x: 0, y: Double(exported.height))
        preview.scaleBy(x: 1, y: -1)
        preview.scaleBy(x: 2, y: 2)
        PanelRenderer.draw(design, in: preview,
                           size: CGSize(width: Double(exported.width) / 2, height: Double(exported.height) / 2))
        let previewImage = try XCTUnwrap(preview.makeImage())
        XCTAssertEqual(exported.dataProvider?.data as Data?, previewImage.dataProvider?.data as Data?)
        let directory = URL(fileURLWithPath: "/tmp/PanelsArtifacts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try PNGExporter.write(design, resolution: .standard,
                              to: directory.appendingPathComponent("Serge Prototype.png"))
    }

    func testLongCaptionDoesNotCoverTheLEMOSocket() throws {
        for control in [ControlKind.lemo1B302, .lemo1B303, .lemo1B304] {
            var design = PanelDesign(title: "")
            let address = CellAddress(row: 0, column: 0)
            design[address].setControl(control)
            let plain = try PNGExporter.image(design, resolution: .standard)
            design[address].caption = String(repeating: "LONG CONTROL NAME ", count: 12)
            let captioned = try PNGExporter.image(design, resolution: .standard)
            let original = try XCTUnwrap(plain.dataProvider?.data as Data?)
            let modified = try XCTUnwrap(captioned.dataProvider?.data as Data?)
            for y in 204..<397 {
                let start = y * plain.bytesPerRow + 91 * 4
                let range = start..<(start + 193 * 4)
                XCTAssertEqual(original.subdata(in: range), modified.subdata(in: range),
                               "The caption changed \(control.partName) pixels at row \(y)")
            }
        }
    }
}
