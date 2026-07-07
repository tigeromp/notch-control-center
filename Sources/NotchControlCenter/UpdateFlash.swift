import SwiftUI

enum UpdateFlashKind: Equatable {
    case up
    case down
    case accent
}

struct UpdateFlashState: Equatable {
    let kind: UpdateFlashKind
    let generation: Int
}

struct UpdateFlashPulse: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let kind: UpdateFlashKind
    let trigger: Int

    @State private var opacity: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(flashColor)
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear { runPulse() }
            .onChange(of: trigger) { _, _ in runPulse() }
    }

    private func runPulse() {
        guard trigger > 0 else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            opacity = 0.62
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.9)) {
                opacity = 0
            }
        }
    }

    private var flashColor: Color {
        switch kind {
        case .up: return .green
        case .down: return .red
        case .accent: return appearance.accentColor
        }
    }
}

enum UpdateFlashTracker {
    static func minuteDirection(
        timeline: [(price: Double, date: Date)],
        currentPrice: Double
    ) -> UpdateFlashKind? {
        guard let oldest = timeline.first else { return nil }
        if currentPrice > oldest.price * 1.00001 { return .up }
        if currentPrice < oldest.price * 0.99999 { return .down }
        return nil
    }

    static func tickDirection(previous: Double?, current: Double) -> UpdateFlashKind? {
        guard let previous else { return nil }
        if current > previous { return .up }
        if current < previous { return .down }
        return nil
    }
}
