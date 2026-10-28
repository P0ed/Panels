import SwiftUI

struct PanelInspector: View {
    @Binding var design: PanelDesign
    @Binding var state: PanelEditorState
    var editor: PanelEditor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                panelSettings
                Divider()
                if let address = state.selection {
                    cellSettings(address, cell: design[address])
                        .id(address)
                } else {
                    ContentUnavailableView {
                        Label("Select a cell", systemImage: "square.dashed")
                    } description: {
                        Text("Click a cell on the panel to choose its control, label, and frame.")
                    }
                    .padding(.vertical, 30)
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .frame(minWidth: 290, idealWidth: 310, maxWidth: 340)
    }

    private var panelSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("PANEL")
            VStack(alignment: .leading, spacing: 6) {
                Text("Module name").font(.subheadline).foregroundStyle(.secondary)
                TextField("Module name", text: editor.panelBinding(\.title,
                          actionName: "Change Module Name"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .accessibilityIdentifier("moduleTitle")
            }
            Picker("Grid size", selection: editor.panelBinding(\.size,
                   actionName: "Change Panel Size")) {
                ForEach(PanelSize.allCases) { size in
                    Text(size.gridLabel).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("panelSize")
            Picker("Panel finish", selection: editor.panelBinding(\.finish,
                   actionName: "Change Panel Finish")) {
                ForEach(PanelFinish.allCases) { finish in
                    Text(finish.name).tag(finish)
                }
            }
            .accessibilityIdentifier("panelFinish")
            HStack {
                Text(design.size.dimensionLabel).foregroundStyle(.primary)
                Spacer()
                Text("1″ spacing").foregroundStyle(.secondary)
            }
            .font(.caption)
            if design.size == .fourBySix {
                let hiddenCount = (0..<6).flatMap { row in
                    (4..<8).map { CellAddress(row: row, column: $0) }
                }.filter { design[$0].hasContent }.count
                if hiddenCount > 0 {
                    Text("\(hiddenCount) cells retained in hidden columns.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func cellSettings(_ address: CellAddress, cell: PanelCell) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    sectionTitle("CELL")
                    Text(address.label).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: editor.clearCell) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(!cell.hasContent)
                .help("Clear this cell")
                .accessibilityLabel("Clear cell")
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ControlKind.allCases) { kind in
                    controlTile(kind, selected: cell.control == kind)
                }
            }
            HStack(spacing: 5) {
                if let control = cell.control {
                    Text(control.partName).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Empty cell").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if cell.control != nil {
                    Button("Remove") { editor.setControl(nil) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .help("Remove the control and keep the caption and frame")
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Control name").font(.subheadline).foregroundStyle(.secondary)
                TextField("Optional", text: editor.cellBinding(\.caption,
                          actionName: "Change Control Name"),
                          axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .accessibilityIdentifier("controlCaption")
            }
            if let control = cell.control, !control.colors.isEmpty {
                Picker("Color", selection: editor.cellBinding(\.color,
                       actionName: "Change Control Color")) {
                    ForEach(control.colors) { color in
                        Label {
                            Text(color.name)
                        } icon: {
                            Image(nsImage: colorSwatch(color))
                        }
                        .tag(color)
                    }
                }
            }
            if cell.control == .bourns51 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Pointer")
                        Spacer()
                        Text("\(Int(cell.knobAngle))°").monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: editor.cellBinding(\.knobAngle, actionName: "Rotate Knob"),
                           in: -150...150, step: 5)
                        .accessibilityLabel("Knob pointer angle")
                }
                .font(.subheadline)
            }
            if cell.control == .nkkMN12 {
                Picker("Lever", selection: editor.cellBinding(\.togglePosition,
                       actionName: "Change Toggle Position")) {
                    ForEach(TogglePosition.allCases) { position in
                        Text(position.name).tag(position)
                    }
                }
            }
            Divider()
            sectionTitle("FRAME")
            Picker("Shape", selection: editor.cellBinding(\.frame, actionName: "Change Frame")) {
                ForEach(FramePreset.allCases) { preset in
                    Text(preset.name).tag(preset)
						.keyboardShortcut(preset.shortcut, modifiers: .control)
                }
            }
            if cell.frame != .none, cell.frame != .rectangle {
                Picker("Rotation", selection: editor.cellBinding(\.frameRotation,
                       actionName: "Rotate Frame")) {
                    ForEach(QuarterTurn.allCases) { rotation in
                        Text("\(rotation.degrees)°").tag(rotation)
                    }
                }
                .pickerStyle(.segmented)
            }
            HStack {
                Button("Copy cell", systemImage: "doc.on.doc") { editor.copyCell() }
                Button("Paste", systemImage: "doc.on.clipboard") { editor.pasteCell() }
            }
            .controlSize(.small)
        }
    }

    private func controlTile(_ kind: ControlKind, selected: Bool) -> some View {
        Button { editor.setControl(kind) } label: {
            VStack(spacing: 7) {
                Canvas { context, size in
                    context.withCGContext { cg in
                        let scale = 1.9
                        cg.translateBy(x: size.width / 2, y: size.height / 2)
                        cg.scaleBy(x: scale, y: scale)
                        var cell = PanelCell()
                        cell.setControl(kind)
                        PanelRenderer.drawControl(cell, in: cg, center: .zero)
                    }
                }
                .frame(height: 33)
                Text(kind.name).font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08),
                                  lineWidth: selected ? 1.5 : 0.75)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel("\(kind.name), \(kind.partName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(kind.partName)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
    }

    private func colorSwatch(_ color: PanelColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let ink = color.ink
            NSColor(srgbRed: ink.red, green: ink.green, blue: ink.blue, alpha: 1).setFill()
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            path.fill()
            NSColor.gray.withAlphaComponent(0.4).setStroke()
            path.lineWidth = 0.5
            path.stroke()
            return true
        }
    }
}
