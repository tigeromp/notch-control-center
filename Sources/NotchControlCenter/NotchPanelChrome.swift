import SwiftUI

struct NotchCollapseButton: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.compact.up")
                .font(appearance.font(size: 11, weight: .bold))
                .foregroundStyle(appearance.primaryText.opacity(0.9))
                .frame(width: 22, height: 22)
                .background(appearance.accentColor.opacity(0.2))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Collapse panel (Esc)")
    }
}

struct NotchSettingsButton: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let showSettings: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: showSettings ? "xmark" : "gearshape.fill")
                .font(appearance.font(size: 10, weight: .semibold))
                .foregroundStyle(appearance.primaryText.opacity(0.85))
                .frame(width: 22, height: 22)
                .background(appearance.accentColor.opacity(0.2))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(showSettings ? "Close settings" : "Widget settings")
    }
}

struct NotchCloseHint: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore

    var body: some View {
        Text("Esc · ↑ · click notch · move away to close")
            .font(appearance.font(size: 8, weight: .medium))
            .foregroundStyle(appearance.mutedText.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }
}
