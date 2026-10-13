import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let sergePanel = UTType(exportedAs: "p0.panels.panel", conformingTo: .json)
}

struct PanelDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.sergePanel] }

    var design: PanelDesign

    init(design: PanelDesign = PanelDesign()) {
        self.design = design
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw PanelError.invalidDocument("The panel file could not be read.")
        }
        design = try PanelDesign.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try design.encoded())
    }

    static func example() throws -> Self {
        guard let url = Bundle.main.url(forResource: "Serge Prototype", withExtension: "panel") else {
            throw PanelError.invalidDocument("The example panel could not be found.")
        }
        return PanelDocument(design: try PanelDesign.decode(Data(contentsOf: url)))
    }
}
