import AppKit
import SwiftUI
import XCTest
@testable import Panels

@MainActor
private final class DesignHolder {
    var design = PanelDesign()
    var state = PanelEditorState()
    let clipboard = MemoryCellClipboard()
    let undo = UndoManager()
    private(set) var documentWrites = 0
    private(set) var stateWrites = 0

    init() { undo.groupsByEvent = false }

    var binding: Binding<PanelDesign> {
        Binding(get: { self.design }, set: { self.replace($0) })
    }

    var stateBinding: Binding<PanelEditorState> {
        Binding(get: { self.state }, set: { self.stateWrites += 1; self.state = $0 })
    }

    var editor: PanelEditor {
        PanelEditor(design: binding, state: stateBinding, undoManager: undo, clipboard: clipboard)
    }

    private func replace(_ next: PanelDesign) {
        let previous = design
        guard next != previous else { return }
        undo.registerUndo(withTarget: self) { holder in
            MainActor.assumeIsolated { holder.replace(previous) }
        }
        design = next
        documentWrites += 1
    }
}

@MainActor
private final class MemoryCellClipboard: CellClipboard {
    var cellData: Data?
}

final class PanelEditorTests: XCTestCase {
    @MainActor
    func testInspectorEditChangesOnlyDocumentAndUsesDocumentUndo() async {
        let holder = DesignHolder()
        let editor = holder.editor
        let undo = holder.undo
        let title = editor.panelBinding(\.title, actionName: "Change Module Name")
        title.wrappedValue = "NEW NAME"
        XCTAssertEqual(holder.design.title, "NEW NAME")
        XCTAssertEqual(holder.documentWrites, 1)
        XCTAssertEqual(holder.stateWrites, 0)
        XCTAssertEqual(undo.undoActionName, "Change Module Name")
        undo.undo()
        XCTAssertEqual(holder.design.title, "UNTITLED MODULE")
        XCTAssertFalse(undo.canUndo)
        undo.redo()
        XCTAssertEqual(holder.design.title, "NEW NAME")
    }

    @MainActor
    func testInspectorRefreshEchoDoesNotCommitAnEdit() async {
        let holder = DesignHolder()
        let editor = holder.editor
        let undo = holder.undo
        let frame = editor.cellBinding(\.frame, actionName: "Frame")
        frame.wrappedValue = .none
        XCTAssertEqual(holder.design, PanelDesign())
        XCTAssertEqual(holder.documentWrites, 0)
        XCTAssertEqual(holder.stateWrites, 0)
        XCTAssertFalse(undo.canUndo)
    }

    @MainActor
    func testConsecutiveInspectorEditsPreserveFieldsAndOriginalCell() async {
        let holder = DesignHolder()
        let editor = holder.editor
        let source = CellAddress(row: 0, column: 0)
        let target = CellAddress(row: 0, column: 1)
        let caption = editor.cellBinding(\.caption, actionName: "Name")
        let frame = editor.cellBinding(\.frame, actionName: "Frame")
        caption.wrappedValue = "FIRST"
        caption.wrappedValue = ""
        caption.wrappedValue = "LAST"
        frame.wrappedValue = .dualTriangles
        editor.state.selection = target
        XCTAssertEqual(holder.design[source].caption, "LAST")
        XCTAssertEqual(holder.design[source].frame, .dualTriangles)
        XCTAssertEqual(holder.design[target], PanelCell())
    }

    @MainActor
    func testCurrentDocumentBindingShowsSelectedCellsStoredValues() async {
        let holder = DesignHolder()
        let initialSnapshot = holder.design
        let initialEditor = PanelEditor(design: Binding(
            get: { initialSnapshot }, set: { holder.design = $0 }
        ), state: holder.stateBinding, undoManager: nil, clipboard: holder.clipboard)
        let toggle = CellAddress(row: 2, column: 3)
        holder.design[toggle].setControl(.nkkMN12)
        holder.design[toggle].caption = "MODE"
        holder.design[toggle].frame = .dualTriangles
        holder.design[toggle].frameRotation = .two
        holder.design[toggle].togglePosition = .down
        let pot = CellAddress(row: 4, column: 1)
        holder.design[pot].setControl(.bourns51)
        holder.design[pot].caption = "RATE"
        holder.design[pot].frame = .arch
        holder.design[pot].knobAngle = -65
        XCTAssertEqual(initialEditor.selectedCell, PanelCell())
        let editor = holder.editor
        editor.state.selection = toggle
        XCTAssertEqual(editor.cellBinding(\.caption, actionName: "Name").wrappedValue, "MODE")
        XCTAssertEqual(editor.cellBinding(\.frame, actionName: "Frame").wrappedValue, .dualTriangles)
        XCTAssertEqual(editor.cellBinding(\.frameRotation, actionName: "Rotate").wrappedValue, .two)
        XCTAssertEqual(editor.cellBinding(\.togglePosition, actionName: "Lever").wrappedValue, .down)
        editor.state.selection = pot
        XCTAssertEqual(editor.cellBinding(\.caption, actionName: "Name").wrappedValue, "RATE")
        XCTAssertEqual(editor.cellBinding(\.frame, actionName: "Frame").wrappedValue, .arch)
        XCTAssertEqual(editor.cellBinding(\.knobAngle, actionName: "Pointer").wrappedValue, -65)
        editor.cellBinding(\.caption, actionName: "Name").wrappedValue = "SPEED"
        XCTAssertEqual(holder.design[pot].caption, "SPEED")
        XCTAssertEqual(holder.design[toggle].caption, "MODE")
    }

    @MainActor
    func testPanelFinishChangesAreUndoable() async {
        let holder = DesignHolder()
        let editor = holder.editor
        let undo = holder.undo
        editor.setFinish(.enig)
        XCTAssertEqual(holder.design.finish, .enig)
        undo.undo()
        XCTAssertEqual(holder.design.finish, .enamel)
        undo.redo()
        XCTAssertEqual(holder.design.finish, .enig)
    }

    @MainActor
    func testLEMOPinCountChangesPreserveCellSettingsAndSupportUndoRedo() async {
        let holder = DesignHolder()
        let editor = holder.editor
        let undo = holder.undo
        let address = CellAddress(row: 0, column: 0)
        editor.state.selection = address
        editor.setControl(.lemo1B303)
        editor.editCell("Style Cell") {
            $0.caption = "BAL. OUT"
            $0.frame = .dualTriangles
            $0.frameRotation = .one
        }
        let pins = editor.cellBinding(\.control, actionName: "Change LEMO Pin Count")
        for control in [ControlKind.lemo1B302, .lemo1B304, .lemo1B303] {
            let original = holder.design[address]
            var expected = original
            expected.control = control
            pins.wrappedValue = control
            XCTAssertEqual(holder.design[address], expected)
            XCTAssertTrue(control.isLEMO)
            XCTAssertEqual(undo.undoActionName, "Change LEMO Pin Count")
            undo.undo()
            XCTAssertEqual(holder.design[address], original)
            undo.redo()
            XCTAssertEqual(holder.design[address], expected)
        }
    }

    @MainActor
    func testResizeRetainsCellsAndSupportsUndoRedo() async {
        let holder = DesignHolder()
        let editor = holder.editor
        let undo = holder.undo
        editor.setSize(.eightBySix)
        let address = CellAddress(row: 3, column: 7)
        editor.state.selection = address
        editor.setControl(.lemo1B303)
        editor.cellBinding(\.caption, actionName: "Name Control").wrappedValue = "BAL. OUT"
        editor.setSize(.fourBySix)
        XCTAssertEqual(holder.design[address].caption, "BAL. OUT")
        XCTAssertEqual(editor.state.selection, CellAddress(row: 3, column: 3))
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
        let clipboard = holder.clipboard
        let editor = holder.editor
        let undo = holder.undo
        let source = CellAddress(row: 0, column: 0)
        let target = CellAddress(row: 5, column: 3)
        editor.state.selection = source
        editor.setControl(.pomona1581)
        editor.editCell("Style Cell") {
            $0.color = .red
            $0.caption = "CYCLE"
            $0.frame = .dualTriangles
        }
        editor.copyCell()
        XCTAssertNotNil(clipboard.cellData)
        editor.state.selection = target
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
        let editor = holder.editor
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
        let editor = holder.editor
        let undo = holder.undo
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
        let editor = holder.editor
        let source = CellAddress(row: 0, column: 0)
        let target = CellAddress(row: 0, column: 1)
        let caption = editor.cellBinding(\.caption, actionName: "Change Control Name")
        editor.state.selection = target
        caption.wrappedValue = "FINISH EDIT"
        XCTAssertEqual(holder.design[source].caption, "FINISH EDIT")
        XCTAssertEqual(holder.design[target].caption, "")
    }

    @MainActor
    func testInvalidClipboardDataDoesNotModifyThePanel() async {
        let holder = DesignHolder()
        let clipboard = holder.clipboard
        let editor = holder.editor
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
        let editor = holder.editor
        editor.state.fitZoom = 1.5
        editor.zoomIn()
        XCTAssertEqual(editor.state.zoom, 1.75)
        editor.state.zoom = nil
        editor.zoomOut()
        XCTAssertEqual(editor.state.zoom, 1.25)
        editor.state.zoom = 4
        editor.zoomIn()
        XCTAssertEqual(editor.state.zoom, 4)
        editor.state.zoom = 0.25
        editor.zoomOut()
        XCTAssertEqual(editor.state.zoom, 0.25)
    }
}
