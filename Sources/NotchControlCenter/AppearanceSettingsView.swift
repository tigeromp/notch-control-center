import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var appearance: NotchAppearanceStore
    var compact = false
    var onBack: (() -> Void)?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: compact ? 12 : 16) {
                if let onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Widgets")
                        }
                        .font(compact ? .system(size: 11, weight: .semibold) : .body)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(appearance.accentColor)
                }

                header

                appearanceSection(title: "Text") {
                    sliderRow(
                        label: "Size",
                        value: $appearance.textScale,
                        range: 0.85...1.35,
                        format: "%.0f%%",
                        display: { "\(Int($0 * 100))%" }
                    )
                    sliderRow(
                        label: "Brightness",
                        value: $appearance.textOpacity,
                        range: 0.65...1.0,
                        format: "%.0f%%",
                        display: { "\(Int($0 * 100))%" }
                    )
                    sliderRow(
                        label: "Muted text",
                        value: $appearance.mutedOpacity,
                        range: 0.2...0.7,
                        format: "%.0f%%",
                        display: { "\(Int($0 * 100))%" }
                    )
                }

                appearanceSection(title: "Accent color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                        ForEach(NotchAccentPreset.allCases) { preset in
                            Button {
                                appearance.accentPreset = preset
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hue: preset.hue, saturation: 0.72, brightness: 0.95))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(appearance.accentPreset == preset ? 0.9 : 0), lineWidth: 2)
                                        )
                                    Text(preset.label)
                                        .font(.system(size: compact ? 9 : 10, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    appearance.accentPreset == preset
                                        ? Color.white.opacity(0.12)
                                        : Color.white.opacity(0.05)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                appearanceSection(title: "Panel") {
                    sliderRow(
                        label: "Background opacity",
                        value: $appearance.panelOpacity,
                        range: 0.65...1.0,
                        format: "%.0f%%",
                        display: { "\(Int($0 * 100))%" }
                    )
                    sliderRow(
                        label: "Background shade",
                        value: $appearance.panelBrightness,
                        range: 0.02...0.18,
                        format: "%.2f",
                        display: { String(format: "%.0f%%", $0 * 100) }
                    )
                }

                appearanceSection(title: "Preview") {
                    previewCard
                }

                Button("Reset to defaults") {
                    appearance.resetToDefaults()
                }
                .font(compact ? .system(size: 11, weight: .semibold) : .body)
            }
            .padding(compact ? 0 : 4)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Appearance & Format")
                .font(compact ? .system(size: 13, weight: .bold) : .title3.bold())
            Text("Customize text size, colors, and panel look.")
                .font(compact ? .system(size: 10) : .caption)
                .foregroundStyle(compact ? appearance.mutedText : .secondary)
        }
    }

    @ViewBuilder
    private func appearanceSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(compact ? .system(size: 11, weight: .bold) : .headline)
                .foregroundStyle(compact ? appearance.mutedText : .primary)
            content()
        }
    }

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String,
        display: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(compact ? appearance.font(size: 11, weight: .medium) : .subheadline)
                Spacer()
                Text(display(value.wrappedValue))
                    .font(compact ? appearance.font(size: 10, weight: .semibold, design: .monospaced) : .caption.monospaced())
                    .foregroundStyle(compact ? appearance.mutedText : .secondary)
            }
            Slider(value: value, in: range)
                .tint(appearance.accentColor)
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(appearance.font(size: 9))
                    .foregroundStyle(appearance.accentColor)
                Text("Music")
                    .font(appearance.font(size: 9, weight: .semibold))
                    .foregroundStyle(appearance.mutedText)
            }
            Text("Sample Track Title")
                .font(appearance.font(size: 12, weight: .semibold))
                .foregroundStyle(appearance.primaryText)
            Text("Artist Name · 3:42")
                .font(appearance.font(size: 10, weight: .medium))
                .foregroundStyle(appearance.mutedText)
            Text("AAPL 212.50 +1.2%")
                .font(appearance.font(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(appearance.primaryText)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appearance.panelFill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(appearance.accentColor.opacity(0.35), lineWidth: 1)
        )
    }
}
