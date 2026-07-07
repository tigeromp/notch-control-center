import SwiftUI

/// Continuous horizontal marquee — drag to scroll manually, auto-advances when idle.
struct MarqueeTicker<Content: View>: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let placeholder: String
    let isEmpty: Bool
    let contentSignature: String
    @ViewBuilder let track: () -> Content

    @State private var offset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0
    @State private var isDragging = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var lastSignature: String = ""

    private let speed: CGFloat = 42
    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            if isEmpty {
                Text(placeholder)
                    .font(appearance.font(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(appearance.mutedText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 0) {
                    measuredTrack
                    measuredTrack
                }
                .offset(x: offset)
                .frame(width: max(trackWidth * 2, geo.size.width), alignment: .leading)
                .clipped()
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .onReceive(tick) { _ in advanceFrame() }
                .onAppear { syncSignature(reset: true) }
                .onChange(of: contentSignature) { _, _ in syncSignature(reset: false) }
            }
        }
        .clipped()
    }

    private var measuredTrack: some View {
        track()
            .fixedSize()
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateTrackWidth(proxy.size.width) }
                        .onChange(of: proxy.size.width) { _, width in
                            updateTrackWidth(width)
                        }
                }
            )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartOffset = offset
                }
                offset = dragStartOffset + value.translation.width
                normalizeOffset()
            }
            .onEnded { _ in
                isDragging = false
                normalizeOffset()
            }
    }

    private func updateTrackWidth(_ width: CGFloat) {
        guard width > 0, abs(width - trackWidth) > 0.5 else { return }
        trackWidth = width
        normalizeOffset()
    }

    private func syncSignature(reset: Bool) {
        if reset || contentSignature != lastSignature {
            lastSignature = contentSignature
            if reset || trackWidth == 0 {
                offset = 0
            }
        }
    }

    private func advanceFrame() {
        guard trackWidth > 0, !isDragging else { return }
        offset -= speed / 60.0
        normalizeOffset()
    }

    private func normalizeOffset() {
        guard trackWidth > 0 else { return }
        while offset <= -trackWidth {
            offset += trackWidth
        }
        while offset > 0 {
            offset -= trackWidth
        }
    }
}

struct TextTickerStrip: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let items: [String]
    let placeholder: String

    var body: some View {
        MarqueeTicker(
            placeholder: placeholder,
            isEmpty: items.isEmpty,
            contentSignature: items.joined(separator: "|")
        ) {
            HStack(spacing: 20) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .font(appearance.font(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(appearance.primaryText.opacity(0.9))
                        .lineLimit(1)
                }
            }
        }
    }
}

struct StockTickerStrip: View {
    let quotes: [StockQuote]
    let placeholder: String
    var flashes: [String: UpdateFlashState] = [:]

    var body: some View {
        MarqueeTicker(
            placeholder: placeholder,
            isEmpty: quotes.isEmpty,
            contentSignature: quotes.map { "\($0.id)|\($0.price)|\($0.changePercent)" }.joined(separator: ";")
        ) {
            HStack(spacing: 20) {
                ForEach(quotes) { quote in
                    StockQuoteChip(
                        quote: quote,
                        compact: true,
                        flash: flashes[quote.id]
                    )
                }
            }
        }
    }
}

struct SportsTickerStrip: View {
    let scores: [SportsScore]
    let placeholder: String
    var flashes: [String: UpdateFlashState] = [:]

    var body: some View {
        MarqueeTicker(
            placeholder: placeholder,
            isEmpty: scores.isEmpty,
            contentSignature: scores.map { "\($0.id)|\($0.awayScore)|\($0.homeScore)|\($0.status)" }.joined(separator: ";")
        ) {
            HStack(spacing: 20) {
                ForEach(scores) { score in
                    SportsScoreChip(
                        score: score,
                        flash: flashes[score.id]
                    )
                }
            }
        }
    }
}
