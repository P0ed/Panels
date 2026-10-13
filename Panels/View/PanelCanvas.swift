import SwiftUI

struct PanelCanvas: View {
    var design: PanelDesign
    @ObservedObject var editor: PanelEditor
    @FocusState private var hasFocus: Bool

    var body: some View {
        GeometryReader { geometry in
            let millimeters = CGSize(width: Double(design.size.width) / 1_000,
                                     height: Double(design.size.height) / 1_000)
            let fitScale = min(max(1, geometry.size.width - 88) / millimeters.width,
                               max(1, geometry.size.height - 88) / millimeters.height)
            let scale = editor.zoom.map { $0 * 72 / 25.4 } ?? fitScale
            let canvasSize = CGSize(width: millimeters.width * scale,
                                    height: millimeters.height * scale)

            ScrollView([.horizontal, .vertical]) {
                Canvas { context, size in
                    context.withCGContext { cg in
                        PanelRenderer.draw(design, in: cg, size: size)
                    }
                    if editor.showGuides {
                        for address in design.geometry.addresses {
                            let rect = displayRect(address, scale: scale)
                            context.stroke(Path(rect), with: .color(.black.opacity(0.12)),
                                           style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        }
                    }
                    if let hovered = editor.hovered, hovered != editor.selection {
                        context.fill(Path(roundedRect: displayRect(hovered, scale: scale).insetBy(dx: 1, dy: 1),
                                          cornerRadius: 2),
                                     with: .color(.accentColor.opacity(0.045)))
                    }
                    if let selection = editor.selection, design.geometry.contains(selection) {
                        let rect = displayRect(selection, scale: scale).insetBy(dx: 1.5, dy: 1.5)
                        context.fill(Path(roundedRect: rect, cornerRadius: 2),
                                     with: .color(.accentColor.opacity(0.055)))
                        context.stroke(Path(roundedRect: rect, cornerRadius: 2),
                                       with: .color(.accentColor), lineWidth: 2)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
                .contentShape(Rectangle())
                .gesture(SpatialTapGesture().onEnded { event in
                    editor.selection = address(at: event.location, scale: scale)
                    hasFocus = true
                })
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let address = address(at: location, scale: scale)
                        if editor.hovered != address { editor.hovered = address }
                    case .ended: editor.hovered = nil
                    }
                }
                .focusable()
                .focused($hasFocus)
                .focusEffectDisabled()
                .onMoveCommand(perform: editor.moveSelection)
                .onDeleteCommand(perform: editor.clearCell)
                .onExitCommand { editor.selection = nil }
                .accessibilityLabel("Panel canvas")
                .accessibilityChildren {
                    ForEach(design.geometry.addresses) { address in
                        Button {
                            editor.selection = address
                            hasFocus = true
                        } label: {
                            Text("\(address.label), \(design[address].control?.name ?? "Empty"), \(design[address].caption)")
                        }
                    }
                }
                .padding(44)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
            .onChange(of: fitScale, initial: true) { _, scale in
                editor.fitZoom = scale * 25.4 / 72
            }
            .background(Color(nsColor: .underPageBackgroundColor))
        }
    }

    private func displayRect(_ address: CellAddress, scale: Double) -> CGRect {
        let rect = PanelRenderer.screenRect(design.geometry.rect(for: address), panelHeight: design.size.height)
        return CGRect(x: rect.minX * scale, y: rect.minY * scale,
                      width: rect.width * scale, height: rect.height * scale)
    }

    private func address(at location: CGPoint, scale: Double) -> CellAddress? {
        let point = PhysicalPoint(x: Int(location.x / scale * 1_000),
                                  y: design.size.height - Int(location.y / scale * 1_000))
        return design.geometry.address(at: point)
    }
}
