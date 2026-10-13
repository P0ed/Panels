import SwiftUI

enum ToolbarSpacing: ViewModifier {
    case label
    case control

    func body(content: Content) -> some View {
        content.padding(insets)
    }

    private var insets: EdgeInsets {
        switch self {
        case .label:
            EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
        case .control:
            EdgeInsets(top: 0, leading: 2, bottom: 0, trailing: 2)
        }
    }
}
