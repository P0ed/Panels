import SwiftUI

struct EditorView: View {
    @Binding var design: PanelDesign
    @State private var state = PanelEditorState()
    @Environment(\.undoManager) private var undoManager

    private var editor: PanelEditor {
        PanelEditor(design: $design, state: $state, undoManager: undoManager)
    }

    var body: some View {
        NavigationSplitView {
            PanelInspector(design: $design, state: $state, editor: editor)
                .navigationSplitViewColumnWidth(min: 290, ideal: 310, max: 340)
        } detail: {
            VStack(spacing: 0) {
                PanelCanvas(design: design, state: $state, editor: editor)
                statusBar
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 780, minHeight: 650)
        .focusedSceneValue(\.panelEditor, editor)
        .onChange(of: design.size) { _, size in state.constrainSelection(to: size) }
        .toolbar { editorToolbar }
        .alert("Panels", isPresented: Binding(
            get: { state.exportError != nil },
            set: { if !$0 { state.exportError = nil } }
        )) {
            Button("OK", role: .cancel) { state.exportError = nil }
        } message: {
            Text(state.exportError ?? "")
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
            if let selection = state.selection {
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
            Toggle(isOn: $state.showGuides) {
                Label("Cell Guides", systemImage: "square.dashed")
            }
            .toggleStyle(.button)
            .help("Show cell guides")

            Menu {
                Button("Fit Panel") { state.zoom = nil }
                Divider()
                ForEach([0.5, 0.75, 1, 1.5, 2, 3, 4], id: \.self) { zoom in
                    Button("\(Int(zoom * 100))%") { state.zoom = zoom }
                }
            } label: {
                Text(state.zoom.map { "\(Int($0 * 100))%" } ?? "Fit")
                    .monospacedDigit()
                    .frame(minWidth: 34)
                    .modifier(ToolbarSpacing.label)
            }
            .modifier(ToolbarSpacing.control)
            .help("Preview zoom")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
				ForEach(ExportResolution.allCases) { resolution in
					Button(resolution.label) { state.exportResolution = resolution }
				}
            } label: {
                Text(state.exportResolution.label).font(.subheadline).monospacedDigit()
                    .modifier(ToolbarSpacing.label)
            }
            .modifier(ToolbarSpacing.control)
            .help("PNG export resolution")

			Button(action: editor.exportPNG) {
				if state.isExporting {
					ProgressView().controlSize(.small)
				} else {
					Image(systemName: "square.and.arrow.up")
				}
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.isExporting)
            .help("Export the panel artwork as a PNG image")
        }
    }
}
