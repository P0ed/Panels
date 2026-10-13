import Foundation

enum PanelSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case fourBySix
    case eightBySix

    var id: Self { self }
    var columns: Int { self == .fourBySix ? 4 : 8 }
    var rows: Int { 6 }
    var width: Int { self == .fourBySix ? 107_950 : 215_900 }
    var height: Int { 177_800 }
    var gridLabel: String { "\(columns) × 6" }
    var dimensionLabel: String { self == .fourBySix ? "4.25″ × 7″" : "8.5″ × 7″" }
}

enum ControlKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case lemo1B303
    case pomona1581
    case nkkMN12
    case nkkMBNF15
    case vccCLB300
    case bourns51

    var id: Self { self }

    var name: String {
        switch self {
        case .lemo1B303: "LEMO socket"
        case .pomona1581: "Banana jack"
        case .nkkMN12: "Toggle"
        case .nkkMBNF15: "Button"
        case .vccCLB300: "LED lens"
        case .bourns51: "Potentiometer"
        }
    }

    var partName: String {
        switch self {
        case .lemo1B303: "LEMO.1B.303"
        case .pomona1581: "4 mm · Pomona 1581"
        case .nkkMN12: "SPDT · NKK MN12"
        case .nkkMBNF15: "SPDT · NKK MBNF15"
        case .vccCLB300: "LED · VCC CLB-300"
        case .bourns51: "Bourns 51"
        }
    }

    var colors: [PanelColor] {
        switch self {
        case .pomona1581: [.white, .black, .red, .blue, .green, .yellow, .orange, .brown, .violet, .gray]
        case .nkkMBNF15: [.black, .white, .red, .yellow, .green, .blue]
        case .vccCLB300: [.amber, .red, .green, .blue, .white, .yellow]
        case .lemo1B303, .nkkMN12, .bourns51: []
        }
    }

    var defaultColor: PanelColor {
        switch self {
        case .pomona1581: .white
        case .vccCLB300: .amber
        default: .black
        }
    }
}

enum PanelColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case white, black, red, blue, green, yellow, orange, brown, violet, gray, amber

    var id: Self { self }
    var name: String { rawValue.capitalized }
}

enum PanelFinish: String, Codable, CaseIterable, Identifiable, Sendable {
    case enig, aluminum, enamel

    var id: Self { self }
    var name: String {
        switch self {
        case .enig: "ENIG"
        case .aluminum: "Aluminum"
        case .enamel: "Enamel"
        }
    }
}

enum FramePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, rectangle, diamond, arch, peak

    var id: Self { self }
    var name: String { rawValue.capitalized }
}

enum QuarterTurn: Int, Codable, CaseIterable, Identifiable, Sendable {
    case zero, one, two, three

    var id: Self { self }
    var degrees: Int { rawValue * 90 }
}

enum TogglePosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case up, down

    var id: Self { self }
    var name: String { rawValue.capitalized }
}

struct CellAddress: Hashable, Identifiable, Sendable {
    var row: Int
    var column: Int

    var id: Int { row * 8 + column }
    var label: String { "Row \(row + 1) · Column \(column + 1)" }
}

struct PhysicalPoint: Equatable, Sendable {
    var x: Int
    var y: Int
}

struct PhysicalRect: Equatable, Sendable {
    var origin: PhysicalPoint
    var width: Int
    var height: Int

    var center: PhysicalPoint {
        PhysicalPoint(x: origin.x + width / 2, y: origin.y + height / 2)
    }
}

struct MountingHole: Equatable, Sendable {
    var center: PhysicalPoint
    var diameter: Int
}

struct PanelGeometry: Sendable {
    static let pitch = 25_400
    static let verticalInset = 12_700

    var size: PanelSize
    var horizontalInset: Int { (size.width - size.columns * Self.pitch) / 2 }

    var mountingHoles: [MountingHole] {
        [9_000, size.width - 9_000].flatMap { x in
            [6_500, size.height - 6_500].map { y in
                MountingHole(center: PhysicalPoint(x: x, y: y), diameter: 3_200)
            }
        }
    }

    var addresses: [CellAddress] {
        (0..<size.rows).flatMap { row in
            (0..<size.columns).map { CellAddress(row: row, column: $0) }
        }
    }

    func rect(for address: CellAddress) -> PhysicalRect {
        PhysicalRect(
            origin: PhysicalPoint(
                x: horizontalInset + address.column * Self.pitch,
                y: size.height - Self.verticalInset - (address.row + 1) * Self.pitch
            ),
            width: Self.pitch,
            height: Self.pitch
        )
    }

    func address(at point: PhysicalPoint) -> CellAddress? {
        let x = point.x - horizontalInset
        let y = point.y - Self.verticalInset
        guard x >= 0, x < size.columns * Self.pitch,
              y >= 0, y < size.rows * Self.pitch else { return nil }
        return CellAddress(row: size.rows - 1 - y / Self.pitch, column: x / Self.pitch)
    }

    func contains(_ address: CellAddress) -> Bool {
        (0..<size.rows).contains(address.row) && (0..<size.columns).contains(address.column)
    }
}

struct PanelCell: Equatable, Codable, Sendable {
    var control: ControlKind?
    var caption = ""
    var color: PanelColor = .white
    var frame: FramePreset = .none
    var frameRotation: QuarterTurn = .zero
    var knobAngle: Double = 45
    var togglePosition: TogglePosition = .up

    var hasContent: Bool { control != nil || !caption.isEmpty || frame != .none }

    mutating func setControl(_ control: ControlKind?) {
        self.control = control
        if let control { color = control.defaultColor }
    }

    func validate() throws {
        guard knobAngle.isFinite, (-150...150).contains(knobAngle) else {
            throw PanelError.invalidDocument("A knob angle is outside its supported range.")
        }
        if let control, !control.colors.isEmpty, !control.colors.contains(color) {
            throw PanelError.invalidDocument("A control has an unsupported color.")
        }
    }
}

struct PanelDesign: Equatable, Codable, Sendable {
    var version = 1
    var size: PanelSize = .fourBySix
    var title = "UNTITLED MODULE"
    var finish: PanelFinish = .enamel
    var cells = Array(repeating: PanelCell(), count: 48)

    var geometry: PanelGeometry { PanelGeometry(size: size) }
    var visibleControlCount: Int {
        geometry.addresses.filter { self[$0].control != nil }.count
    }

    subscript(address: CellAddress) -> PanelCell {
        get { cells[address.id] }
        set { cells[address.id] = newValue }
    }

    func validate() throws {
        guard version == 1 else {
            throw PanelError.invalidDocument("This panel uses an unsupported file version.")
        }
        guard cells.count == 48 else {
            throw PanelError.invalidDocument("A panel must contain 48 stored cell slots.")
        }
        for cell in cells { try cell.validate() }
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Self {
        do {
            let design = try JSONDecoder().decode(Self.self, from: data)
            try design.validate()
            return design
        } catch let error as PanelError {
            throw error
        } catch {
            throw PanelError.invalidDocument("The file is not a valid Panels document.")
        }
    }
}

extension PanelDesign {
    private enum CodingKeys: String, CodingKey {
        case version, size, title, finish, cells
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: try values.decode(Int.self, forKey: .version),
            size: try values.decode(PanelSize.self, forKey: .size),
            title: try values.decode(String.self, forKey: .title),
            finish: try values.decodeIfPresent(PanelFinish.self, forKey: .finish) ?? .enamel,
            cells: try values.decode([PanelCell].self, forKey: .cells)
        )
    }
}

enum PanelError: LocalizedError {
    case invalidDocument(String)
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .invalidDocument(let message): message
        case .exportFailed: "The panel image could not be generated."
        }
    }
}
