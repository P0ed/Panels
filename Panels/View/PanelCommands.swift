import AppKit
import SwiftUI

struct PanelCommands: Commands {
    @FocusedValue(\.panelEditor) private var editor
    @Environment(\.newDocument) private var newDocument

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Example Panel") {
                do {
                    let example = try PanelDocument.example()
                    newDocument(example)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Could not open example"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(after: .importExport) {
            Button("Export PNG…") { editor?.exportPNG() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(editor == nil || editor?.isExporting == true)
        }
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") { perform(#selector(NSText.cut(_:))) { $0.cutCell() } }
                .keyboardShortcut("x")
                .disabled(!canCopy)
            Button("Copy") { perform(#selector(NSText.copy(_:))) { $0.copyCell() } }
                .keyboardShortcut("c")
                .disabled(!canCopy)
            Button("Paste") { perform(#selector(NSText.paste(_:))) { $0.pasteCell() } }
                .keyboardShortcut("v")
                .disabled(!isEditingText && (editor?.selection == nil || editor?.canPaste != true))
        }
        CommandMenu("Panel") {
            Button("Clear Cell") { editor?.clearCell() }
                .disabled(editor?.selectedCell?.hasContent != true || isEditingText)
            Divider()
            Button("4 × 6 Cells") { editor?.setSize(.fourBySix) }.disabled(editor == nil)
            Button("8 × 6 Cells") { editor?.setSize(.eightBySix) }.disabled(editor == nil)
        }
        CommandGroup(after: .toolbar) {
            Divider()
            Button("Zoom In") { editor?.zoomIn() }.keyboardShortcut("+").disabled(editor == nil)
            Button("Zoom Out") { editor?.zoomOut() }.keyboardShortcut("-").disabled(editor == nil)
            Button("Fit Panel") { editor?.zoom = nil }
                .keyboardShortcut("0")
                .disabled(editor == nil)
            Toggle("Cell Guides", isOn: Binding(
                get: { editor?.showGuides ?? true },
                set: { editor?.showGuides = $0 }
            ))
            .keyboardShortcut("g")
            .disabled(editor == nil)
        }
    }

    private var isEditingText: Bool { NSApp.keyWindow?.firstResponder is NSTextView }
    private var canCopy: Bool { isEditingText || editor?.selection != nil }

    private func perform(_ selector: Selector, cellAction: (PanelEditor) -> Void) {
        if isEditingText {
            NSApp.sendAction(selector, to: nil, from: nil)
        } else if let editor {
            cellAction(editor)
        }
    }
}
