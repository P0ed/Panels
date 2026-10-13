import AppKit

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
