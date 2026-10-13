import SwiftUI

@main
struct PanelsApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: PanelDocument()) { configuration in
            EditorView(design: configuration.$document.design)
        }
        .defaultSize(width: 1_180, height: 840)
        .windowToolbarStyle(.unified)
        .commands { PanelCommands() }
    }
}
