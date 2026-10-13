import XCTest
@testable import Panels

func exampleDesign() throws -> PanelDesign {
#if SWIFT_PACKAGE
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Examples/Serge Prototype.panel")
    return try PanelDesign.decode(Data(contentsOf: url))
#else
    return try PanelDocument.example().design
#endif
}

final class PanelModelTests: XCTestCase {
    func testMountingHolesUseSpecifiedOffsetsAndDiameterForBothSizes() {
        for size in PanelSize.allCases {
            let holes = PanelGeometry(size: size).mountingHoles
            XCTAssertEqual(holes.count, 4)
            XCTAssertEqual(Set(holes.map(\.center.x)), [9_000, size.width - 9_000])
            XCTAssertEqual(Set(holes.map(\.center.y)), [6_500, size.height - 6_500])
            XCTAssertTrue(holes.allSatisfy { $0.diameter == 3_200 })
        }
    }

    func testFinishesRoundTripAndLegacyDocumentsKeepEnamel() throws {
        for finish in PanelFinish.allCases {
            let design = PanelDesign(finish: finish)
            XCTAssertEqual(try PanelDesign.decode(design.encoded()).finish, finish)
        }
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(
            with: PanelDesign(finish: .enig).encoded()
        ) as? [String: Any])
        legacy.removeValue(forKey: "finish")
        let restored = try PanelDesign.decode(JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(restored.finish, .enamel)
    }

    func testPanelDimensionsAndCenteredOneInchGrid() {
        for size in PanelSize.allCases {
            let geometry = PanelGeometry(size: size)
            XCTAssertEqual(size.height, 177_800)
            XCTAssertEqual(geometry.addresses.count, size.columns * 6)
            let first = geometry.rect(for: CellAddress(row: 0, column: 0))
            let last = geometry.rect(for: CellAddress(row: 5, column: size.columns - 1))
            XCTAssertEqual(first.origin.x, size.width - last.origin.x - last.width)
            XCTAssertEqual(first.center.y, 152_400)
            XCTAssertEqual(last.center.y, 25_400)
            for row in 0..<6 {
                for column in 0..<size.columns {
                    let address = CellAddress(row: row, column: column)
                    let center = geometry.rect(for: address).center
                    XCTAssertEqual(geometry.address(at: center), address)
                    if column > 0 {
                        let previous = geometry.rect(for: CellAddress(row: row, column: column - 1)).center
                        XCTAssertEqual(center.x - previous.x, 25_400)
                    }
                    if row > 0 {
                        let previous = geometry.rect(for: CellAddress(row: row - 1, column: column)).center
                        XCTAssertEqual(previous.y - center.y, 25_400)
                    }
                }
            }
        }
        XCTAssertEqual(PanelSize.fourBySix.width, 107_950)
        XCTAssertEqual(PanelSize.eightBySix.width, 215_900)
    }

    func testHeaderFooterAndSideMarginsAreNotCells() {
        let geometry = PanelGeometry(size: .fourBySix)
        for point in [
            PhysicalPoint(x: 0, y: 50_000),
            PhysicalPoint(x: 107_949, y: 50_000),
            PhysicalPoint(x: 50_000, y: 177_799),
            PhysicalPoint(x: 50_000, y: 0),
            PhysicalPoint(x: -1, y: 50_000),
        ] {
            XCTAssertNil(geometry.address(at: point))
        }
        XCTAssertEqual(geometry.address(at: PhysicalPoint(x: 3_175, y: 12_700)),
                       CellAddress(row: 5, column: 0))
        XCTAssertNil(geometry.address(at: PhysicalPoint(x: 104_775, y: 12_700)))
    }

    func testDocumentRoundTripIncludesHiddenCellsAndUnicode() throws {
        var design = PanelDesign()
        design.title = "SLOPE & ÉTAGE"
        let hidden = CellAddress(row: 5, column: 7)
        design[hidden].setControl(.vccCLB300)
        design[hidden].caption = "CV ± / Ω\nGate"
        design[hidden].frame = .arch
        design[hidden].frameRotation = .three
        let restored = try PanelDesign.decode(design.encoded())
        XCTAssertEqual(restored, design)
        XCTAssertEqual(restored.size, .fourBySix)
        XCTAssertEqual(restored[hidden].caption, "CV ± / Ω\nGate")
    }

    func testInvalidDocumentsAreRejected() throws {
        var design = PanelDesign()
        design.version = 2
        XCTAssertThrowsError(try design.encoded())
        design.version = 1
        design.cells.removeLast()
        XCTAssertThrowsError(try design.encoded())
        XCTAssertThrowsError(try PanelDesign.decode(Data("not JSON".utf8)))
        XCTAssertThrowsError(try PanelDesign.decode(Data("{}".utf8)))
        var cell = PanelCell(control: .pomona1581, color: .amber)
        XCTAssertThrowsError(try cell.validate())
        cell.setControl(.bourns51)
        cell.knobAngle = .infinity
        XCTAssertThrowsError(try cell.validate())
    }

    func testExampleContainsEveryControlAndFrame() throws {
        let example = try exampleDesign()
        XCTAssertEqual(example.size, .eightBySix)
        XCTAssertEqual(Set(example.cells.compactMap(\.control)), Set(ControlKind.allCases))
        XCTAssertEqual(Set(example.cells.map(\.frame)), Set(FramePreset.allCases))
        XCTAssertEqual(try PanelDesign.decode(example.encoded()), example)
    }
}
