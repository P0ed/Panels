import AppKit
import SwiftUI

struct PanelEditorState: Equatable, Sendable {
    var selection: CellAddress? = CellAddress(row: 0, column: 0)
    var hovered: CellAddress?
    var zoom: Double?
    var fitZoom = 1.0
    var showGuides = false
    var exportResolution: ExportResolution = .standard
    var exportError: String?
    var isExporting = false
    var clipboardRevision = 0

    mutating func constrainSelection(to size: PanelSize) {
        if let selection, selection.column >= size.columns {
            self.selection = CellAddress(row: selection.row, column: size.columns - 1)
        }
        if let hovered, hovered.column >= size.columns {
            self.hovered = nil
        }
    }
}

@MainActor
struct PanelEditor {
    @Binding var design: PanelDesign
    @Binding var state: PanelEditorState
    var undoManager: UndoManager?
    var clipboard: any CellClipboard = SystemCellClipboard()

    var selectedCell: PanelCell? { state.selection.map { design[$0] } }
    var canPaste: Bool { clipboard.cellData != nil }

    func change(_ name: String, _ mutation: (inout PanelDesign) -> Void) {
        var updated = design
        mutation(&updated)
        guard updated != design else { return }
        let needsGroup = undoManager.map {
            $0.groupingLevel == 0 && !$0.isUndoing && !$0.isRedoing
        } ?? false
        if needsGroup { undoManager?.beginUndoGrouping() }
        defer { if needsGroup { undoManager?.endUndoGrouping() } }
        design = updated
        undoManager?.setActionName(name)
        if state.selection.map({ !updated.geometry.contains($0) }) == true
            || state.hovered.map({ !updated.geometry.contains($0) }) == true {
            state.constrainSelection(to: updated.size)
        }
    }

    func setSize(_ size: PanelSize) {
        change("Change Panel Size") { $0.size = size }
    }

    func setTitle(_ title: String) {
        change("Change Module Name") { $0.title = title }
    }

    func setFinish(_ finish: PanelFinish) {
        change("Change Panel Finish") { $0.finish = finish }
    }

    func editCell(_ name: String, _ mutation: (inout PanelCell) -> Void) {
        guard let selection = state.selection else { return }
        change(name) { mutation(&$0[selection]) }
    }

    func panelBinding<Value: Equatable>(_ keyPath: WritableKeyPath<PanelDesign, Value>,
                                        actionName: String) -> Binding<Value> {
        Binding(
            get: { design[keyPath: keyPath] },
            set: { value in change(actionName) { $0[keyPath: keyPath] = value } }
        )
    }

    func cellBinding<Value: Equatable>(_ keyPath: WritableKeyPath<PanelCell, Value>,
                                       actionName: String) -> Binding<Value> {
        let address = state.selection
        return Binding(
            get: { address.map { design[$0][keyPath: keyPath] } ?? PanelCell()[keyPath: keyPath] },
            set: { value in
                guard let address else { return }
                change(actionName) { $0[address][keyPath: keyPath] = value }
            }
        )
    }

    func setControl(_ kind: ControlKind?) {
        editCell("Change Control") { $0.setControl(kind) }
    }

    func clearCell() {
        editCell("Clear Cell") { $0 = PanelCell() }
    }

    func copyCell() {
        guard let selectedCell, let data = try? JSONEncoder().encode(selectedCell) else { return }
        clipboard.cellData = data
        state.clipboardRevision += 1
    }

    func pasteCell() {
        guard state.selection != nil,
              let data = clipboard.cellData,
              let cell = try? JSONDecoder().decode(PanelCell.self, from: data),
              (try? cell.validate()) != nil else { return }
        editCell("Paste Cell") { $0 = cell }
    }

    func cutCell() {
        copyCell()
        clearCell()
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        var address = state.selection ?? CellAddress(row: 0, column: 0)
        switch direction {
        case .left: address.column = max(0, address.column - 1)
        case .right: address.column = min(design.size.columns - 1, address.column + 1)
        case .up: address.row = max(0, address.row - 1)
        case .down: address.row = min(5, address.row + 1)
        @unknown default: break
        }
        state.selection = address
    }

    func zoomIn() { state.zoom = min(4, (state.zoom ?? state.fitZoom) + 0.25) }
    func zoomOut() { state.zoom = max(0.25, (state.zoom ?? state.fitZoom) - 0.25) }

    func exportPNG() {
        let panel = NSSavePanel()
        panel.title = "Export Panel as PNG"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        let title = design.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = (title.isEmpty ? "Panel" : title)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "\(stem).png"
        let pixels = state.exportResolution.pixels(for: design.size)
        panel.message = "\(pixels.width) × \(pixels.height) pixels · \(state.exportResolution.label)"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in writePNG(to: url) }
        }
    }

    private func writePNG(to url: URL) {
        let snapshot = design
        let resolution = state.exportResolution
        state.isExporting = true
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    try PNGExporter.write(snapshot, resolution: resolution, to: url)
                }.value
            } catch {
                state.exportError = error.localizedDescription
            }
            state.isExporting = false
        }
    }
}

struct PanelEditorKey: FocusedValueKey {
    typealias Value = PanelEditor
}

extension FocusedValues {
    var panelEditor: PanelEditor? {
        get { self[PanelEditorKey.self] }
        set { self[PanelEditorKey.self] = newValue }
    }
}
