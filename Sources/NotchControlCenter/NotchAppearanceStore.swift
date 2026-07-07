import SwiftUI

enum NotchAccentPreset: String, CaseIterable, Identifiable {
    case blue
    case mint
    case orange
    case purple
    case pink
    case cyan

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }

    var hue: Double {
        switch self {
        case .blue: return 0.58
        case .mint: return 0.45
        case .orange: return 0.08
        case .purple: return 0.78
        case .pink: return 0.92
        case .cyan: return 0.50
        }
    }
}

final class NotchAppearanceStore: ObservableObject {
    @Published var textScale: Double {
        didSet { save(Keys.textScale, textScale) }
    }
    @Published var accentPreset: NotchAccentPreset {
        didSet { save(Keys.accentPreset, accentPreset.rawValue) }
    }
    @Published var textOpacity: Double {
        didSet { save(Keys.textOpacity, textOpacity) }
    }
    @Published var mutedOpacity: Double {
        didSet { save(Keys.mutedOpacity, mutedOpacity) }
    }
    @Published var panelOpacity: Double {
        didSet { save(Keys.panelOpacity, panelOpacity) }
    }
    @Published var panelBrightness: Double {
        didSet { save(Keys.panelBrightness, panelBrightness) }
    }

    private enum Keys {
        static let textScale = "appearance.textScale"
        static let accentPreset = "appearance.accentPreset"
        static let textOpacity = "appearance.textOpacity"
        static let mutedOpacity = "appearance.mutedOpacity"
        static let panelOpacity = "appearance.panelOpacity"
        static let panelBrightness = "appearance.panelBrightness"
    }

    init() {
        let defaults = UserDefaults.standard
        textScale = defaults.object(forKey: Keys.textScale) as? Double ?? 1.0
        let presetRaw = defaults.string(forKey: Keys.accentPreset) ?? NotchAccentPreset.blue.rawValue
        accentPreset = NotchAccentPreset(rawValue: presetRaw) ?? .blue
        textOpacity = defaults.object(forKey: Keys.textOpacity) as? Double ?? 1.0
        mutedOpacity = defaults.object(forKey: Keys.mutedOpacity) as? Double ?? 0.45
        panelOpacity = defaults.object(forKey: Keys.panelOpacity) as? Double ?? 0.92
        panelBrightness = defaults.object(forKey: Keys.panelBrightness) as? Double ?? 0.08
    }

    var accentColor: Color {
        Color(hue: accentPreset.hue, saturation: 0.72, brightness: 0.95)
    }

    var primaryText: Color {
        .white.opacity(textOpacity)
    }

    var mutedText: Color {
        .white.opacity(mutedOpacity)
    }

    var panelFill: Color {
        Color(white: panelBrightness, opacity: panelOpacity)
    }

    func scaled(_ size: CGFloat) -> CGFloat {
        size * textScale
    }

    func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: scaled(size), weight: weight, design: design)
    }

    func resetToDefaults() {
        textScale = 1.0
        accentPreset = .blue
        textOpacity = 1.0
        mutedOpacity = 0.45
        panelOpacity = 0.92
        panelBrightness = 0.08
    }

    private func save(_ key: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func save(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
