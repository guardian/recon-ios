import SwiftUI

extension View {
    /// Applies `.sectionIndexLabel(_:)` on iOS 26+, no-op on earlier versions.
    @ViewBuilder
    func sectionIndexLabelIfAvailable(_ label: String) -> some View {
        if #available(iOS 26.0, *) {
            self.sectionIndexLabel(label)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func listSectionIndexVisibilityIfAvailable(
        _ visibility: Visibility
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.listSectionIndexVisibility(visibility)
        } else {
            self
        }
    }
}
