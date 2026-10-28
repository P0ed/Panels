import CoreGraphics
import CoreText
import Foundation

struct PanelInk: Sendable {
    var red: Double
    var green: Double
    var blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> 16) & 255) / 255
        green = Double((hex >> 8) & 255) / 255
        blue = Double(hex & 255) / 255
    }

    var cgColor: CGColor { CGColor(red: red, green: green, blue: blue, alpha: 1) }
}

extension PanelColor {
    var ink: PanelInk {
        switch self {
        case .white: PanelInk(0xFCFCFA)
        case .black: PanelInk(0x242522)
        case .red: PanelInk(0xC41A2B)
        case .blue: PanelInk(0x3474AD)
        case .green: PanelInk(0x397257)
        case .yellow: PanelInk(0xE7BC32)
        case .orange: PanelInk(0xDD782E)
        case .brown: PanelInk(0x785041)
        case .violet: PanelInk(0x7E539A)
        case .gray: PanelInk(0x8C908B)
        case .amber: PanelInk(0xE4B021)
        }
    }
}

extension PanelFinish {
    var ink: PanelInk {
        switch self {
        case .enig: PanelInk(0xD9BC70)
        case .aluminum: PanelInk(0xD4D7D8)
        case .enamel: PanelInk(0xEBE5D9)
        }
    }
}

enum PanelTypography {
    static let fontData: Data? = {
#if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "FuturaMedium", withExtension: "otf",
                                    subdirectory: "Resources")
#else
        let url: URL? = Bundle.main.url(forResource: "FuturaMedium", withExtension: "otf")
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Panels/Resources/FuturaMedium.otf")
#endif
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }()

    static func font(size: Double) -> CTFont {
        if let fontData, let provider = CGDataProvider(data: fontData as CFData),
           let font = CGFont(provider) {
            return CTFontCreateWithGraphicsFont(font, size, nil, nil)
        }
        return CTFontCreateWithName("Futura-Medium" as CFString, size, nil)
    }
}

enum PanelRenderer {
    static var paper: CGColor { PanelFinish.enamel.ink.cgColor }
    static var ink: CGColor { PanelInk(0x262724).cgColor }
    static var frameInk: CGColor { PanelInk(0x858881).cgColor }

    static func draw(_ design: PanelDesign, in context: CGContext, size: CGSize) {
        let width = Double(design.size.width) / 1_000
        let height = Double(design.size.height) / 1_000
        context.saveGState()
        defer { context.restoreGState() }
        context.scaleBy(x: size.width / width, y: size.height / height)
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        let panel = CGRect(x: 0, y: 0, width: width, height: height)
        let background = design.finish.ink.cgColor
        context.setFillColor(background)
        context.fill(panel)
        context.setStrokeColor(ink)
        context.setLineWidth(0.18)
        context.addPath(CGPath(roundedRect: panel.insetBy(dx: 0.12, dy: 0.12),
                               cornerWidth: 0.65, cornerHeight: 0.65, transform: nil))
        context.strokePath()

        context.setFillColor(PanelInk(0x5B6059).cgColor)
        for hole in design.geometry.mountingHoles {
            let center = CGPoint(x: Double(hole.center.x) / 1_000,
                                 y: Double(design.size.height - hole.center.y) / 1_000)
            circle(in: context, center: center, radius: Double(hole.diameter) / 2_000)
            context.fillPath()
        }

        for address in design.geometry.addresses {
            let cell = design[address]
            let rect = screenRect(design.geometry.rect(for: address), panelHeight: design.size.height)
            drawFrame(cell.frame, rotation: cell.frameRotation, in: context, rect: rect)
        }
        for address in design.geometry.addresses {
            let cell = design[address]
            let rect = screenRect(design.geometry.rect(for: address), panelHeight: design.size.height)
            drawControl(cell, in: context, center: CGPoint(x: rect.midX, y: rect.midY))
            if !cell.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                drawText(cell.caption, in: context,
                         rect: CGRect(x: rect.minX + 0.8, y: rect.minY + 21.1,
                                      width: rect.width - 1.6, height: 4.1),
                         fontSize: 2.45, minimumFontSize: 1.65, maxLines: 2,
						 tracking: 0.035)
            }
        }
        drawText(design.title, in: context,
                 rect: CGRect(x: 13, y: 1.1, width: width - 26, height: 10.2),
                 fontSize: 3.65, minimumFontSize: 2.2, maxLines: 2,
                 tracking: 0.17)
    }

    static func screenRect(_ rect: PhysicalRect, panelHeight: Int) -> CGRect {
        CGRect(x: Double(rect.origin.x) / 1_000,
               y: Double(panelHeight - rect.origin.y - rect.height) / 1_000,
               width: Double(rect.width) / 1_000,
               height: Double(rect.height) / 1_000)
    }

    static func drawFrame(_ preset: FramePreset, rotation: QuarterTurn,
                          in context: CGContext, rect: CGRect) {
        guard preset != .none else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: Double(rotation.degrees) * .pi / 180)
        context.translateBy(x: -rect.width / 2, y: -rect.height / 2)
        context.setStrokeColor(frameInk)
        context.setLineWidth(0.26)
        context.setLineJoin(.miter)
        context.setLineCap(.butt)
        let width = rect.width
        let height = rect.height
        switch preset {
        case .none: break
        case .rectangle:
            context.addRect(CGRect(x: 0, y: 0, width: width, height: height))
        case .dualTriangles:
            let inset: CGFloat = 0.33
            context.translateBy(x: inset, y: inset)
            let width = rect.width - 2 * inset
            let height = rect.height - 2 * inset
            for (baseX, tipX) in [(width * 0.45, 0.0), (width * 0.55, width)] {
                context.move(to: CGPoint(x: baseX, y: 0))
                context.addLine(to: CGPoint(x: tipX, y: height / 2))
                context.addLine(to: CGPoint(x: baseX, y: height))
                context.closePath()
            }
        case .arch:
            context.move(to: CGPoint(x: 0, y: height))
            context.addLine(to: CGPoint(x: 0, y: 6.4))
            context.addCurve(to: CGPoint(x: width, y: 6.4),
                             control1: CGPoint(x: width * 0.26, y: -1.7),
                             control2: CGPoint(x: width * 0.74, y: -1.7))
            context.addLine(to: CGPoint(x: width, y: height))
            context.closePath()
        case .peak:
            context.move(to: CGPoint(x: 0, y: height))
            context.addLine(to: CGPoint(x: 0, y: 7.8))
            context.addLine(to: CGPoint(x: width / 2, y: 0))
            context.addLine(to: CGPoint(x: width, y: 7.8))
            context.addLine(to: CGPoint(x: width, y: height))
            context.closePath()
        case .triangle:
            context.move(to: CGPoint(x: 0, y: height / 2))
            context.addLine(to: CGPoint(x: width / 2, y: 0))
            context.addLine(to: CGPoint(x: width, y: height / 2))
            context.closePath()
        case .cross:
            context.move(to: .zero)
            context.addLine(to: CGPoint(x: width, y: height))
            context.move(to: CGPoint(x: 0, y: height))
            context.addLine(to: CGPoint(x: width, y: 0))
        case .angle:
            context.move(to: .zero)
            context.addLine(to: CGPoint(x: width, y: 0))
            context.addLine(to: CGPoint(x: width, y: height))
            context.closePath()
        }
        context.strokePath()
    }

    static func drawControl(_ cell: PanelCell, in context: CGContext, center: CGPoint) {
        guard let control = cell.control else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: center.x, y: center.y)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch control {
        case .lemo1B302: drawLEMO(pinCount: 2, in: context)
        case .lemo1B303: drawLEMO(pinCount: 3, in: context)
        case .lemo1B304: drawLEMO(pinCount: 4, in: context)
        case .pomona1581: drawBanana(cell.color, in: context)
        case .nkkMN12: drawToggle(cell.togglePosition, in: context)
        case .nkkMBNF15: drawButton(cell.color, in: context)
        case .vccCLB300: drawLens(cell.color, in: context)
        case .bourns51: drawKnob(angle: cell.knobAngle, in: context)
        }
    }

    private static func drawBanana(_ color: PanelColor, in context: CGContext) {
        context.setFillColor(color.ink.cgColor)
        context.setStrokeColor(PanelInk(0xCFCEC8).cgColor)
        context.setLineWidth(0.13)
        circle(in: context, radius: 6.35)
        context.drawPath(using: .fillStroke)
        context.setFillColor(PanelInk(0x555955).cgColor)
        context.setStrokeColor(PanelInk(0xA4A69F).cgColor)
        circle(in: context, radius: 2.15)
        context.drawPath(using: .fillStroke)
    }

    private static func drawLEMO(pinCount: Int, in context: CGContext) {
        context.setFillColor(PanelInk(0xD6D4D0).cgColor)
        context.setStrokeColor(PanelInk(0x696B69).cgColor)
        context.setLineWidth(0.18)
        circle(in: context, radius: 8)
        context.drawPath(using: .fillStroke)
        context.setFillColor(PanelInk(0xF2F0EC).cgColor)
        circle(in: context, radius: 6.55)
        context.drawPath(using: .fillStroke)
        for i in 0..<4 {
            let angle = Double(i) * .pi / 2 + .pi / 4
            context.move(to: CGPoint(x: cos(angle) * 7, y: sin(angle) * 7))
            context.addLine(to: CGPoint(x: cos(angle) * 7.9, y: sin(angle) * 7.9))
        }
        context.strokePath()
        context.setFillColor(PanelInk(0x454847).cgColor)
        circle(in: context, radius: 4.65)
        context.drawPath(using: .fillStroke)
        context.setStrokeColor(PanelInk(0xB8BAB5).cgColor)
        circle(in: context, radius: 3.9)
        context.strokePath()
        let phase: Double = switch pinCount {
        case 2: 0
        case 4: .pi / 4
        default: -.pi / 2
        }
        for i in 0..<pinCount {
            let angle = Double(i) * .pi * 2 / Double(pinCount) + phase
            context.setFillColor(PanelInk(0x141615).cgColor)
            circle(in: context, center: CGPoint(x: cos(angle) * 2, y: sin(angle) * 2), radius: 0.68)
            context.drawPath(using: .fillStroke)
        }
        context.setFillColor(PanelInk(0xD6D4D0).cgColor)
        context.fill(CGRect(x: -0.3, y: -4.75, width: 0.6, height: 0.9))
    }

    private static func drawToggle(_ position: TogglePosition, in context: CGContext) {
        context.setFillColor(PanelInk(0xAAA9A3).cgColor)
        context.setStrokeColor(PanelInk(0x737771).cgColor)
        context.setLineWidth(0.15)
        polygon(in: context, sides: 6, radius: 4.25)
        context.drawPath(using: .fillStroke)
        context.setFillColor(PanelInk(0xE4E3DF).cgColor)
        circle(in: context, radius: 2.9)
        context.drawPath(using: .fillStroke)
        context.setFillColor(PanelInk(0x585B56).cgColor)
        circle(in: context, radius: 2.2)
        context.fillPath()
        let end = CGPoint(x: 0, y: position == .up ? -3.8 : 3.8)
        context.setStrokeColor(PanelInk(0xBABDB7).cgColor)
        context.setLineWidth(1.75)
        context.move(to: .zero)
        context.addLine(to: end)
        context.strokePath()
        context.setFillColor(PanelInk(0xCCCDC8).cgColor)
        context.setStrokeColor(PanelInk(0x81867D).cgColor)
        context.setLineWidth(0.17)
        circle(in: context, center: end, radius: 1.25)
        context.drawPath(using: .fillStroke)
    }

    private static func drawButton(_ color: PanelColor, in context: CGContext) {
        context.setFillColor(PanelInk(0xCBCDC6).cgColor)
        context.setStrokeColor(PanelInk(0x7C8178).cgColor)
        context.setLineWidth(0.15)
        polygon(in: context, sides: 6, radius: 4.9)
        context.drawPath(using: .fillStroke)
        context.setFillColor(color.ink.cgColor)
        circle(in: context, radius: 4)
        context.drawPath(using: .fillStroke)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.23))
        circle(in: context, radius: 3.55)
        context.strokePath()
    }

    private static func drawLens(_ color: PanelColor, in context: CGContext) {
        context.setFillColor(color.ink.cgColor)
        context.setStrokeColor(PanelInk(0xBA962E).cgColor)
        context.setLineWidth(0.12)
        circle(in: context, radius: 3.555)
        context.drawPath(using: .fillStroke)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.38))
        for radius in [2.95, 2.35, 1.75, 1.15, 0.55] {
            circle(in: context, radius: radius)
            context.strokePath()
        }
    }

    private static func drawKnob(angle: Double, in context: CGContext) {
        let path = CGMutablePath()
        for i in 0..<120 {
            let a = Double(i) * .pi * 2 / 120
            let radius = 6.05 + 0.35 * cos(a * 10)
            let point = CGPoint(x: cos(a) * radius, y: sin(a) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(ink)
        context.fillPath()
        let angle = angle * .pi / 180
        context.setStrokeColor(PanelInk(0xF4F2EA).cgColor)
        context.setLineWidth(0.3)
        context.move(to: CGPoint(x: sin(angle) * 1.85, y: -cos(angle) * 1.85))
        context.addLine(to: CGPoint(x: sin(angle) * 4.9, y: -cos(angle) * 4.9))
        context.strokePath()
    }

    private static func circle(in context: CGContext, center: CGPoint = .zero, radius: Double) {
        context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                     width: radius * 2, height: radius * 2))
    }

    private static func polygon(in context: CGContext, sides: Int, radius: Double) {
        for i in 0..<sides {
            let angle = Double(i) * .pi * 2 / Double(sides)
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 { context.move(to: point) } else { context.addLine(to: point) }
        }
        context.closePath()
    }

    private static func attributed(_ text: String, fontSize: Double, tracking: Double) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String):
                PanelTypography.font(size: fontSize),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink,
            NSAttributedString.Key(kCTKernAttributeName as String): tracking,
        ])
    }

    private static func textLines(_ text: String, fontSize: Double, width: Double,
                                  tracking: Double, limit: Int) -> (lines: [CTLine], overflow: Bool) {
        let attributed = attributed(text, fontSize: fontSize, tracking: tracking)
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        var offset = 0
        var lines: [CTLine] = []
        while offset < attributed.length, lines.count < limit {
            let length = max(1, CTTypesetterSuggestLineBreak(typesetter, offset, width))
            lines.append(CTTypesetterCreateLine(typesetter, CFRange(location: offset, length: length)))
            offset += length
        }
        return (lines, offset < attributed.length)
    }

    private static func drawText(_ text: String, in context: CGContext, rect: CGRect,
                                 fontSize initialSize: Double, minimumFontSize: Double,
                                 maxLines: Int, tracking: Double) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !text.isEmpty else { return }
        var fontSize = initialSize
        var result = textLines(text, fontSize: fontSize, width: rect.width,
                               tracking: tracking, limit: maxLines + 1)
        while fontSize > minimumFontSize,
              result.overflow || result.lines.count > maxLines ||
                Double(result.lines.count) * fontSize * 1.22 > rect.height {
            fontSize = max(minimumFontSize, fontSize - 0.1)
            result = textLines(text, fontSize: fontSize, width: rect.width,
                               tracking: tracking, limit: maxLines + 1)
        }
        var lines = Array(result.lines.prefix(maxLines))
        if result.overflow || result.lines.count > maxLines {
            let token = CTLineCreateWithAttributedString(attributed("…", fontSize: fontSize, tracking: tracking))
            let last = CTLineCreateWithAttributedString(attributed(
                remainingText(text, after: lines.dropLast()),
                fontSize: fontSize, tracking: tracking
            ))
            lines[lines.count - 1] = CTLineCreateTruncatedLine(last, rect.width, .end, token) ?? token
        }
        let lineHeight = fontSize * 1.22
        let blockHeight = Double(lines.count) * lineHeight
        let startY = rect.midY - blockHeight / 2
        let widths = lines.map { CTLineGetTypographicBounds($0, nil, nil, nil) }

        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: rect.insetBy(dx: -0.7, dy: -0.35))

		for (index, line) in lines.enumerated() {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, nil)
            let baseline = startY + Double(index) * lineHeight + (lineHeight + ascent - descent) / 2
            context.saveGState()
            context.translateBy(x: rect.midX - widths[index] / 2, y: baseline)
            context.scaleBy(x: 1, y: -1)
            context.textMatrix = .identity
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    private static func remainingText(_ text: String, after lines: ArraySlice<CTLine>) -> String {
        let offset = lines.reduce(0) { $0 + CTLineGetStringRange($1).length }
        return (text as NSString).substring(from: offset)
    }
}
