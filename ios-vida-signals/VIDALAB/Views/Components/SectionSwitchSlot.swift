import SwiftUI

extension EnvironmentValues {
    /// The Lab or Library section switch, handed down by its shell so each
    /// section can show it under its own top bar: orbit mark first, then the
    /// switch, then the page, as in the approved design.
    @Entry var vidaSectionSwitch: AnyView? = nil
}

private struct SectionSwitchSlot: ViewModifier {
    @Environment(\.vidaSectionSwitch) private var sectionSwitch

    func body(content: Content) -> some View {
        if let sectionSwitch {
            content.safeAreaInset(edge: .top, spacing: 0) { sectionSwitch }
        } else {
            content
        }
    }
}

extension View {
    /// Shows the shell's section switch, if there is one, just below the top
    /// bar. Apply inside the section's `NavigationStack`, next to `.vidaMenu()`.
    func vidaSectionSwitch() -> some View {
        modifier(SectionSwitchSlot())
    }
}
