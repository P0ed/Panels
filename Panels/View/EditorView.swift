import SwiftUI

struct EditorView: View {
    @Binding var design: PanelDesign
    @StateObject private var editor: PanelEditor
    @Environment(\.undoManager) private var undoManager

    init(design: Binding<PanelDesign>) {
        _design = design
        _editor = StateObject(wrappedValue: PanelEditor(design: design))
    }

    var body: some View {
        editor.updateDocumentBinding($design)
        return NavigationSplitView {
            PanelInspector(design: design, editor: editor)
                .navigationSplitViewColumnWidth(min: 290, ideal: 310, max: 340)
        } detail: {
            VStack(spacing: 0) {
                PanelCanvas(design: design, editor: editor)
                statusBar
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 780, minHeight: 650)
        .focusedSceneValue(\.panelEditor, editor)
        .onAppear { editor.undoManager = undoManager }
        .onChange(of: undoManager) { _, manager in editor.undoManager = manager }
        .toolbar { editorToolbar }
        .alert("Panels", isPresented: Binding(
            get: { editor.exportError != nil },
            set: { if !$0 { editor.exportError = nil } }
        )) {
            Button("OK", role: .cancel) { editor.exportError = nil }
        } message: {
            Text(editor.exportError ?? "")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.split.3x3")
                .foregroundStyle(.tertiary)
            Text("\(design.size.gridLabel) cells")
            Text("·").foregroundStyle(.tertiary)
            Text(design.size.dimensionLabel)
            Spacer()
            if let selection = editor.selection {
                Text(selection.label).foregroundStyle(.secondary)
            }
            Text("·").foregroundStyle(.tertiary)
            Text("\(design.visibleControlCount) controls").foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Toggle(isOn: $editor.showGuides) {
                Label("Cell Guides", systemImage: "square.dashed")
            }
            .toggleStyle(.button)
            .help("Show cell guides")

            Menu {
                Button("Fit Panel") { editor.zoom = nil }
                Divider()
                ForEach([0.5, 0.75, 1, 1.5, 2, 3, 4], id: \.self) { zoom in
                    Button("\(Int(zoom * 100))%") { editor.zoom = zoom }
                }
            } label: {
                Text(editor.zoom.map { "\(Int($0 * 100))%" } ?? "Fit")
                    .monospacedDigit()
                    .frame(minWidth: 34)
            }
            .help("Preview zoom")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("Image Resolution", selection: $editor.exportResolution) {
                    ForEach(ExportResolution.allCases) { resolution in
                        Text(resolution.label).tag(resolution)
                    }
                }
            } label: {
                Text(editor.exportResolution.label).font(.subheadline).monospacedDigit()
            }
            .help("PNG export resolution")
            Button(action: editor.exportPNG) {
                HStack(spacing: 6) {
                    if editor.isExporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("Export PNG")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(editor.isExporting)
            .help("Export the panel artwork as a PNG image")
        }
    }
}
