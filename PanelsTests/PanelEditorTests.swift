import AppKit
import SwiftUI
import XCTest
@testable import Panels

@MainActor
private final class DesignHolder {
    var design = PanelDesign()
    var binding: Binding<PanelDesign> {
        Binding(get: { self.design }, set: { self.design = $0 })
    }
}

@MainActor
private final class MemoryCellClipboard: CellClipboard {
    var cellData: Data?
}

final class PanelEditorTests: XCTestCase {
    @MainActor
    func testResizeRetainsCellsAndSupportsUndoRedo() async {
        let holder = DesignHolder()
        let editor = PanelEditor(design: holder.binding)
        let undo = UndoManager()
        undo.groupsByEvent = false
        editor.undoManager = undo
        editor.setSize(.eightBySix)
        let address = CellAddress(row: 3, column: 7)
        editor.selection = address
        editor.setControl(.lemo1B303)
        editor.cellBinding(\.caption, actionName: "Name Control").wrappedValue = "BAL. OUT"
        editor.setSize(.fourBySix)
        XCTAssertEqual(holder.design[address].caption, "BAL. OUT")
        XCTAssertEqual(editor.selection, CellAddress(row: 3, column: 3))
        XCTAssertEqual(holder.design.visibleControlCount, 0)
        undo.undo()
        XCTAssertEqual(holder.design.size, .eightBySix)
        XCTAssertEqual(holder.design.visibleControlCount, 1)
        undo.redo()
        XCTAssertEqual(holder.design.size, .fourBySix)
        editor.setSize(.eightBySix)
        XCTAssertEqual(holder.design[address].control, .lemo1B303)
        XCTAssertEqual(holder.design[address].caption, "BAL. OUT")
    }

    @MainActor
    func testCellCopyPasteAndClearAreUndoable() async {
        let holder = DesignHolder()
        let clipboard = MemoryCellClipboard()
        let editor = PanelEditor(design: holder.binding, clipboard: clipboard)
        let undo = UndoManager()
        undo.groupsByEvent = false
        editor.undoManager = undo
        let source = CellAddress(row: 0, column: 0)
        let target = CellAddress(row: 5, column: 3)
        editor.selection = source
        editor.setControl(.pomona1581)
        editor.editCell("Style Cell") {
            $0.color = .red
            $0.caption = "CYCLE"
            $0.frame = .diamond
        }
        editor.copyCell()
        XCTAssertNotNil(clipboard.cellData)
        editor.selection = target
        editor.pasteCell()
        XCTAssertEqual(holder.design[target], holder.design[source])
        editor.clearCell()
        XCTAssertEqual(holder.design[target], PanelCell())
        undo.undo()
        XCTAssertEqual(holder.design[target].caption, "CYCLE")
        undo.undo()
        XCTAssertEqual(holder.design[target], PanelCell())
        undo.redo()
        XCTAssertEqual(holder.design[target].control, .pomona1581)
    }

    @MainActor
    func testTypeChangePreservesLabelAndFrameAndUpdatesDefaultColor() async {
        let holder = DesignHolder()
        let editor = PanelEditor(design: holder.binding)
        editor.editCell("Style") {
            $0.caption = "GATE"
            $0.frame = .peak
        }
        editor.setControl(.vccCLB300)
        XCTAssertEqual(editor.selectedCell?.color, .amber)
        editor.setControl(.nkkMBNF15)
        XCTAssertEqual(editor.selectedCell?.color, .black)
        XCTAssertEqual(editor.selectedCell?.caption, "GATE")
        XCTAssertEqual(editor.selectedCell?.frame, .peak)
        editor.setControl(nil)
        XCTAssertNil(editor.selectedCell?.control)
        XCTAssertEqual(editor.selectedCell?.caption, "GATE")
    }

    @MainActor
    func testTitleUndoAndNoOpEdits() async {
        let holder = DesignHolder()
        let editor = PanelEditor(design: holder.binding)
        let undo = UndoManager()
        undo.groupsByEvent = false
        editor.undoManager = undo
        editor.setTitle(holder.design.title)
        XCTAssertFalse(undo.canUndo)
        editor.setTitle("POSITIVE SLEW")
        undo.undo()
        XCTAssertEqual(holder.design.title, "UNTITLED MODULE")
        undo.redo()
        XCTAssertEqual(holder.design.title, "POSITIVE SLEW")
    }

    @MainActor
    func testCaptionBindingKeepsItsOriginalCellWhenSelectionChanges() async {
        let holder = DesignHolder()
        let editor = PanelEditor(design: holder.binding)
        let source = CellAddress(row: 0, column: 0)
        let target = CellAddress(row: 0, column: 1)
        let caption = editor.cellBinding(\.caption, actionName: "Change Control Name")
        editor.selection = target
        caption.wrappedValue = "FINISH EDIT"
        XCTAssertEqual(holder.design[source].caption, "FINISH EDIT")
        XCTAssertEqual(holder.design[target].caption, "")
    }

    @MainActor
    func testInvalidClipboardDataDoesNotModifyThePanel() async {
        let holder = DesignHolder()
        let clipboard = MemoryCellClipboard()
        let editor = PanelEditor(design: holder.binding, clipboard: clipboard)
        let initial = holder.design
        clipboard.cellData = Data("not a cell".utf8)
        editor.pasteCell()
        XCTAssertEqual(holder.design, initial)
        let invalid = PanelCell(control: .pomona1581, color: .amber)
        clipboard.cellData = try? JSONEncoder().encode(invalid)
        editor.pasteCell()
        XCTAssertEqual(holder.design, initial)
    }

    @MainActor
    func testZoomStartsAtTheFittedScaleAndStaysBounded() async {
        let holder = DesignHolder()
        let editor = PanelEditor(design: holder.binding)
        editor.fitZoom = 1.5
        editor.zoomIn()
        XCTAssertEqual(editor.zoom, 1.75)
        editor.zoom = nil
        editor.zoomOut()
        XCTAssertEqual(editor.zoom, 1.25)
        editor.zoom = 4
        editor.zoomIn()
        XCTAssertEqual(editor.zoom, 4)
        editor.zoom = 0.25
        editor.zoomOut()
        XCTAssertEqual(editor.zoom, 0.25)
    }
}
