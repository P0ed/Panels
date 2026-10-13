import AppKit
import SwiftUI

@MainActor
protocol CellClipboard: AnyObject {
    var cellData: Data? { get set }
}

@MainActor
final class SystemCellClipboard: CellClipboard {
    private let pasteboard = NSPasteboard.general
    private let type = NSPasteboard.PasteboardType("p0.panels.cell")

    var cellData: Data? {
        get { pasteboard.data(forType: type) }
        set {
            pasteboard.clearContents()
            if let newValue { pasteboard.setData(newValue, forType: type) }
        }
    }
}

@MainActor
final class PanelEditor: ObservableObject {
    @Published var selection: CellAddress? = CellAddress(row: 0, column: 0)
    @Published var hovered: CellAddress?
    @Published var zoom: Double?
    @Published var fitZoom = 1.0
    @Published var showGuides = true
    @Published var exportResolution: ExportResolution = .standard
    @Published var exportError: String?
    @Published private(set) var isExporting = false

    private var document: Binding<PanelDesign>
    private let clipboard: any CellClipboard
    weak var undoManager: UndoManager?

    init(design: Binding<PanelDesign>, clipboard: any CellClipboard = SystemCellClipboard()) {
        document = design
        self.clipboard = clipboard
    }

    var design: PanelDesign { document.wrappedValue }
    var selectedCell: PanelCell? { selection.map { design[$0] } }
    var canPaste: Bool { clipboard.cellData != nil }

    func change(_ name: String, _ mutation: (inout PanelDesign) -> Void) {
        var updated = design
        mutation(&updated)
        guard updated != design else { return }
        restore(updated, actionName: name)
    }

    private func restore(_ updated: PanelDesign, actionName: String) {
        let previous = design
        if let undoManager {
            let needsGroup = undoManager.groupingLevel == 0 && !undoManager.isUndoing && !undoManager.isRedoing
            if needsGroup { undoManager.beginUndoGrouping() }
            undoManager.registerUndo(withTarget: self) { editor in
                MainActor.assumeIsolated { editor.restore(previous, actionName: actionName) }
            }
            undoManager.setActionName(actionName)
            if needsGroup { undoManager.endUndoGrouping() }
        }
        document.wrappedValue = updated
        if let selection, !updated.geometry.contains(selection) {
            self.selection = CellAddress(row: selection.row, column: updated.size.columns - 1)
        }
        objectWillChange.send()
    }

    func setSize(_ size: PanelSize) {
        change("Change Panel Size") { $0.size = size }
    }

    func setTitle(_ title: String) {
        change("Change Module Name") { $0.title = title }
    }

    func editCell(_ name: String, _ mutation: (inout PanelCell) -> Void) {
        guard let selection else { return }
        change(name) { mutation(&$0[selection]) }
    }

    func cellBinding<Value>(_ keyPath: WritableKeyPath<PanelCell, Value>, actionName: String) -> Binding<Value> {
        let address = selection
        return Binding(
            get: {
                let cell = address.map { self.design[$0] } ?? PanelCell()
                return cell[keyPath: keyPath]
            },
            set: { value in
                guard let address else { return }
                self.change(actionName) { $0[address][keyPath: keyPath] = value }
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
        objectWillChange.send()
    }

    func pasteCell() {
        guard selection != nil,
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
        var address = selection ?? CellAddress(row: 0, column: 0)
        switch direction {
        case .left: address.column = max(0, address.column - 1)
        case .right: address.column = min(design.size.columns - 1, address.column + 1)
        case .up: address.row = max(0, address.row - 1)
        case .down: address.row = min(5, address.row + 1)
        @unknown default: break
        }
        selection = address
    }

    func zoomIn() { zoom = min(4, (zoom ?? fitZoom) + 0.25) }
    func zoomOut() { zoom = max(0.25, (zoom ?? fitZoom) - 0.25) }

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
        let pixels = exportResolution.pixels(for: design.size)
        panel.message = "\(pixels.width) × \(pixels.height) pixels · \(exportResolution.label)"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { self?.writePNG(to: url) }
        }
    }

    private func writePNG(to url: URL) {
        let snapshot = design
        let resolution = exportResolution
        isExporting = true
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    try PNGExporter.write(snapshot, resolution: resolution, to: url)
                }.value
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
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
