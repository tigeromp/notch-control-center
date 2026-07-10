import AppKit
import SwiftUI

struct NotchGlassBackground<S: Shape>: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let shape: S
    var isCollapsed: Bool = false

    var body: some View {
        if isCollapsed {
            shape.fill(Color.black)
        } else {
            ZStack {
                shape.fill(appearance.panelFill)
                shape.fill(
                    LinearGradient(
                        colors: [
                            appearance.accentColor.opacity(0.14),
                            Color.white.opacity(0.04),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

struct NotchView: View {
    @EnvironmentObject private var notchController: NotchWindowController
    @EnvironmentObject private var appearance: NotchAppearanceStore
    @EnvironmentObject private var music: MusicController
    @EnvironmentObject private var features: NotchFeatureStore
    @EnvironmentObject private var stocks: StockController
    @EnvironmentObject private var calendar: CalendarController
    @EnvironmentObject private var weather: WeatherController
    @EnvironmentObject private var timer: TimerStopwatchController
    @EnvironmentObject private var sports: SportsController
    @EnvironmentObject private var crypto: CryptoController
    @EnvironmentObject private var news: NewsController
    let isExpanded: Bool

    private var topInset: CGFloat {
        isExpanded ? NotchGeometry.primary().expandedTopInset : 0
    }

    private var shape: IntegratedNotchShape {
        IntegratedNotchShape(
            topRadius: isExpanded ? 8 : 5,
            bottomRadius: isExpanded ? 28 : 16
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchGlassBackground(shape: shape, isCollapsed: !isExpanded)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    panelTopBar
                        .padding(.horizontal, 14)
                        .padding(.top, topInset + 6)
                        .padding(.bottom, 4)

                    expandedBody
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if !features.showInlineSettings {
                                features.isHoveringPanelContent = hovering
                            }
                        }
                }
                .overlay(alignment: .top) {
                    Button(action: { notchController.collapseFromNotchTap() }) {
                        Capsule()
                            .fill(Color.clear)
                            .frame(width: 72, height: max(topInset + 4, 20))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Click notch to collapse")
                    .padding(.top, topInset + 6)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        .contentShape(shape)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: features.showInlineSettings)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: features.inlineSettingsPage)
        .scaleEffect(isExpanded ? 1 : 0.96, anchor: .top)
    }

    private var panelTopBar: some View {
        HStack(spacing: 8) {
            NotchCollapseButton(action: { notchController.collapse() })

            if features.showInlineSettings, features.inlineSettingsPage == .appearance {
                Button(action: { features.backToWidgetSettings() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(appearance.font(size: 10, weight: .semibold))
                        Text("Widgets")
                            .font(appearance.font(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(appearance.accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            NotchSettingsButton(
                showSettings: features.showInlineSettings,
                action: { features.toggleInlineSettings() }
            )
        }
        .frame(height: 24)
    }

    @ViewBuilder
    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            if features.showInlineSettings {
                switch features.inlineSettingsPage {
                case .widgets:
                    inlineSettings
                case .appearance:
                    AppearanceSettingsView(
                        appearance: appearance,
                        compact: true,
                        onBack: nil
                    )
                    .padding(.trailing, 8)
                    .onHover { hovering in
                        features.isHoveringInlineSettings = hovering
                    }
                    .onAppear { features.onInteractionFocus?() }
                }
            } else {
                expandedModules
            }
            NotchCloseHint()
        }
    }

    private var expandedModules: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 8) {
                if features.meetingModeEnabled {
                    MeetingModeModule(calendar: calendar)
                }

                if features.timerEnabled {
                    TimerStopwatchModule(timer: timer)
                }

                if features.musicEnabled {
                    musicModule
                }

                if features.weatherEnabled {
                    weatherModule
                }

                if features.stocksEnabled {
                    stockBanner
                }

                if features.cryptoEnabled {
                    cryptoBanner
                }

                if features.sportsEnabled {
                    sportsBanner
                }

                if features.newsEnabled {
                    newsBanner
                }

                if features.calendarEnabled {
                    calendarModule
                }

                if !features.hasAnyWidgetEnabled {
                    Text("Tap ⚙ to enable widgets")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
            .padding(.trailing, 24)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onHover { hovering in
            features.isHoveringPanelContent = hovering
        }
    }

    private var inlineSettings: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Widgets")
                    .font(appearance.font(size: 11, weight: .bold))
                    .foregroundStyle(appearance.mutedText)

                Button(action: { features.openAppearanceSettings() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "paintpalette.fill")
                            .font(appearance.font(size: 12))
                            .foregroundStyle(appearance.accentColor)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Appearance & Format")
                                .font(appearance.font(size: 12, weight: .semibold))
                                .foregroundStyle(appearance.primaryText)
                            Text("Text size, colors, panel style")
                                .font(appearance.font(size: 9))
                                .foregroundStyle(appearance.mutedText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(appearance.font(size: 10, weight: .semibold))
                            .foregroundStyle(appearance.mutedText)
                    }
                }
                .buttonStyle(.plain)

                Divider().opacity(0.2)

                FeatureToggleRow(icon: "music.note", title: "Music", subtitle: "Now playing controls", isOn: $features.musicEnabled)
                    .onChange(of: features.musicEnabled) { _ in features.onLayoutChange?() }

                FeatureToggleRow(icon: "timer", title: "Timer & Stopwatch", subtitle: "Quick timers", isOn: $features.timerEnabled)
                    .onChange(of: features.timerEnabled) { _ in features.onLayoutChange?() }

                FeatureToggleRow(icon: "video.fill", title: "Meeting Mode", subtitle: "Next meeting + Join", isOn: $features.meetingModeEnabled)
                    .onChange(of: features.meetingModeEnabled) { newValue in
                        if newValue { calendar.refresh() }
                        features.onLayoutChange?()
                    }

                FeatureToggleRow(icon: "chart.line.uptrend.xyaxis", title: "Stock Ticker", subtitle: "Watchlist banner", isOn: $features.stocksEnabled)
                    .onChange(of: features.stocksEnabled) { newValue in
                        if newValue { stocks.refresh() }
                        features.onLayoutChange?()
                    }

                if features.stocksEnabled {
                    TextField("AAPL,TSLA,NVDA", text: $stocks.watchlistText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onSubmit { stocks.refresh() }
                }

                FeatureToggleRow(icon: "bitcoinsign.circle", title: "Crypto", subtitle: "BTC, ETH prices", isOn: $features.cryptoEnabled)
                    .onChange(of: features.cryptoEnabled) { newValue in
                        if newValue { crypto.refresh() }
                        features.onLayoutChange?()
                    }

                if features.cryptoEnabled {
                    TextField("BTC-USD,ETH-USD", text: $crypto.watchlistText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onSubmit { crypto.refresh() }
                }

                FeatureToggleRow(icon: "sportscourt", title: "Sports Scores", subtitle: "Live game scores", isOn: $features.sportsEnabled)
                    .onChange(of: features.sportsEnabled) { newValue in
                        if newValue { sports.refresh() }
                        features.onLayoutChange?()
                    }

                if features.sportsEnabled {
                    SportLeaguePicker(sports: sports)
                }

                FeatureToggleRow(icon: "newspaper", title: "News", subtitle: news.regionSubtitle, isOn: $features.newsEnabled)
                    .onChange(of: features.newsEnabled) { newValue in
                        if newValue { news.refresh() }
                        features.onLayoutChange?()
                    }

                FeatureToggleRow(icon: "calendar", title: "Calendar", subtitle: "Today's events", isOn: $features.calendarEnabled)
                    .onChange(of: features.calendarEnabled) { newValue in
                        if newValue { calendar.refresh() }
                        features.onLayoutChange?()
                    }

                FeatureToggleRow(icon: "cloud.sun.fill", title: "Weather", subtitle: "Current conditions", isOn: $features.weatherEnabled)
                    .onChange(of: features.weatherEnabled) { newValue in
                        if newValue { weather.refresh() }
                        features.onLayoutChange?()
                    }

                if features.weatherEnabled {
                    TextField("City, e.g. New York", text: $weather.locationQuery)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onSubmit { weather.refresh() }
                }

                Divider().opacity(0.25)

                Text("Close panel")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))

                Text("↑ button · Esc · click notch · move away · menu bar")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)

                Text("3-finger swipe down opens · move cursor away to close")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onHover { hovering in
            features.isHoveringInlineSettings = hovering
        }
        .onAppear { features.onInteractionFocus?() }
    }

    private var calendarModule: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 9))
                    .foregroundStyle(.blue)
                Text("Today")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }

            if calendar.events.isEmpty {
                Text(calendar.statusMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(calendar.events.prefix(3)) { event in
                        HStack(spacing: 8) {
                            Text(event.timeLabel)
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(width: 52, alignment: .leading)
                            Text(event.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var weatherModule: some View {
        HStack(spacing: 10) {
            Image(systemName: weather.conditionSymbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.yellow.opacity(0.9))
                .frame(width: 28)

            if let temp = weather.temperature {
                Text("\(Int(temp.rounded()))°")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.conditionText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(weather.cityLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            } else {
                Text(weather.isLoading ? "Loading weather…" : weather.statusMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if weather.isLoading {
                ProgressView().controlSize(.mini).scaleEffect(0.55)
            }
        }
    }

    private var musicModule: some View {
        HStack(alignment: .center, spacing: 10) {
            artworkView
                .fixedSize()

            VStack(alignment: .leading, spacing: 3) {
                Text(music.sourceApp)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)

                Text(music.trackTitle.isEmpty ? "Not Playing" : music.trackTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(music.artistName.isEmpty ? "—" : music.artistName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if music.duration > 0 {
                    ProgressSlider(
                        progress: music.progress,
                        duration: music.duration,
                        onSeek: music.seek(to:),
                        onScrubbingChanged: music.setScrubbing
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            VStack(spacing: 5) {
                mediaButton(icon: music.isPlaying ? "pause.fill" : "play.fill", action: music.togglePlayPause)
                HStack(spacing: 4) {
                    mediaButton(icon: "backward.fill", action: music.previousTrack)
                    mediaButton(icon: "forward.fill", action: music.nextTrack)
                }
            }
            .fixedSize()
        }
    }

    private var stockBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetSectionHeader(icon: "chart.line.uptrend.xyaxis", title: "Stocks", tint: .green, isLoading: stocks.isLoading)
            StockTickerStrip(
                quotes: stocks.quotes,
                placeholder: stocks.isLoading ? "Loading quotes…" : stocks.bannerText,
                flashes: stocks.quoteFlashes
            )
            .frame(height: 22)
        }
    }

    private var cryptoBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetSectionHeader(icon: "bitcoinsign.circle", title: "Crypto", tint: .orange, isLoading: crypto.isLoading)
            CryptoTickerStrip(
                quotes: crypto.quotes,
                placeholder: crypto.isLoading ? "Loading crypto…" : crypto.statusMessage
            )
            .frame(height: 22)
        }
    }

    private var sportsBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if sports.leagues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    WidgetSectionHeader(icon: "sportscourt", title: "Sports", tint: .mint, isLoading: sports.isLoading)
                    TextTickerStrip(
                        items: [],
                        placeholder: sports.statusMessage.isEmpty ? "Pick sports in ⚙ settings" : sports.statusMessage
                    )
                    .frame(height: 22)
                }
            } else if sports.hasLiveGames {
                ForEach(sports.leaguesWithLiveGames, id: \.self) { leagueID in
                    if let league = SportsController.league(for: leagueID) {
                        SportLeagueRow(
                            league: league,
                            scores: sports.scores(for: leagueID),
                            placeholder: sports.rowPlaceholder(for: leagueID),
                            flashes: sports.scoreFlashes,
                            isLoading: sports.isLoading
                        )
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    WidgetSectionHeader(icon: "sportscourt", title: "Sports", tint: .mint, isLoading: sports.isLoading)
                    TextTickerStrip(
                        items: [],
                        placeholder: sports.emptyLiveMessage
                    )
                    .frame(height: 22)
                }
            }
        }
    }

    private var newsBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetSectionHeader(
                icon: "newspaper",
                title: "News · \(news.regionLabel)",
                tint: .cyan,
                isLoading: news.isLoading
            )
            TextTickerStrip(
                items: news.headlines.map(\.title),
                placeholder: news.isLoading ? "Loading headlines…" : news.statusMessage
            )
            .frame(height: 22)
        }
    }

    private func mediaButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
        }
        .buttonStyle(GlassIconButtonStyle())
    }

    @ViewBuilder
    private var artworkView: some View {
        Group {
            if let artwork = music.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct StockQuoteChip: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let quote: StockQuote
    var compact: Bool = false
    var flash: UpdateFlashState? = nil

    var body: some View {
        ZStack {
            if let flash {
                UpdateFlashPulse(kind: flash.kind, trigger: flash.generation)
                    .id(flash.generation)
            }
            HStack(spacing: compact ? 4 : 5) {
                Text(quote.symbol)
                    .font(appearance.font(size: compact ? 9 : 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(appearance.primaryText)
                Text(quote.formattedPrice)
                    .font(appearance.font(size: compact ? 9 : 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(appearance.primaryText.opacity(0.85))
                Text(quote.formattedChange)
                    .font(appearance.font(size: compact ? 9 : 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(quote.isUp ? .green : .red)
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background {
            if !compact {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct SportsScoreChip: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let score: SportsScore
    var flash: UpdateFlashState? = nil

    var body: some View {
        ZStack {
            if let flash {
                UpdateFlashPulse(kind: flash.kind, trigger: flash.generation)
                    .id(flash.generation)
            }
            Text(score.headline)
                .font(appearance.font(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(appearance.primaryText.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct FeatureToggleRow: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(appearance.font(size: 12))
                .foregroundStyle(disabled ? appearance.mutedText.opacity(0.5) : appearance.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(appearance.font(size: 12, weight: .semibold))
                    .foregroundStyle(disabled ? appearance.mutedText.opacity(0.6) : appearance.primaryText)
                Text(subtitle)
                    .font(appearance.font(size: 9))
                    .foregroundStyle(appearance.mutedText)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.75)
                .disabled(disabled)
        }
    }
}

struct IntegratedNotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        if #available(macOS 13.0, *) {
            return UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: topRadius,
                style: .continuous
            ).path(in: rect)
        }

        return RoundedRectangle(cornerRadius: bottomRadius, style: .continuous).path(in: rect)
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.5 : 0.95))
            .frame(width: 24, height: 24)
            .background(.white.opacity(configuration.isPressed ? 0.1 : 0.16))
            .clipShape(Circle())
    }
}

struct CollapsedMediaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.45 : 0.92))
            .frame(width: 18, height: 18)
            .background(.white.opacity(configuration.isPressed ? 0.08 : 0.14))
            .clipShape(Circle())
    }
}

struct ProgressSlider: View {
    let progress: Double
    let duration: Double
    let onSeek: (Double) -> Void
    let onScrubbingChanged: (Bool) -> Void

    @State private var dragValue: Double?
    @State private var lastLiveSeek = Date.distantPast

    private var displayValue: Double {
        dragValue ?? min(max(progress, 0), duration)
    }

    var body: some View {
        Slider(
            value: Binding(
                get: { displayValue },
                set: { newValue in
                    dragValue = newValue
                    let now = Date()
                    if now.timeIntervalSince(lastLiveSeek) >= 0.15 {
                        lastLiveSeek = now
                        onSeek(newValue)
                    }
                }
            ),
            in: 0...max(duration, 1),
            onEditingChanged: { editing in
                onScrubbingChanged(editing)
                if editing {
                    dragValue = displayValue
                    lastLiveSeek = .distantPast
                } else if let final = dragValue {
                    onSeek(final)
                    dragValue = nil
                }
            }
        )
        .tint(.white.opacity(0.85))
        .controlSize(.mini)
    }
}

struct AudioVisualizerBars: View {
    @State private var levels: [CGFloat] = [0.3, 0.6, 0.4, 0.8]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.green)
                    .frame(width: 2, height: 10 * levels[index])
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                levels = (0..<levels.count).map { _ in CGFloat.random(in: 0.25...1.0) }
            }
        }
    }
}
