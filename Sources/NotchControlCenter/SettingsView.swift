import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var notchController: NotchWindowController
    @EnvironmentObject private var musicController: MusicController
    @EnvironmentObject private var featureStore: NotchFeatureStore
    @EnvironmentObject private var appearanceStore: NotchAppearanceStore
    @EnvironmentObject private var stockController: StockController

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            appearanceTab
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
        }
        .frame(width: 480, height: 560)
        .onChange(of: featureStore.musicEnabled) { _, _ in notchController.refreshLayout() }
        .onChange(of: featureStore.stocksEnabled) { _, _ in notchController.refreshLayout() }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Widgets") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Music", isOn: $featureStore.musicEnabled)
                        Toggle("Stock Ticker", isOn: $featureStore.stocksEnabled)
                        Toggle("Calendar", isOn: $featureStore.calendarEnabled)
                        Toggle("Weather", isOn: $featureStore.weatherEnabled)
                        Toggle("Timer & Stopwatch", isOn: $featureStore.timerEnabled)
                        Toggle("Sports", isOn: $featureStore.sportsEnabled)
                        Toggle("Crypto", isOn: $featureStore.cryptoEnabled)
                        Toggle("News", isOn: $featureStore.newsEnabled)
                    }
                    .padding(8)
                }

                GroupBox("Stock Watchlist") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter ticker symbols separated by commas:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("AAPL,TSLA,NVDA,MSFT", text: $stockController.watchlistText)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 280)

                        Button("Refresh Quotes") {
                            stockController.refresh()
                        }
                    }
                    .padding(8)
                }

                GroupBox("Notch Panel") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Show notch panel", isOn: $notchController.isVisible)
                        HStack(spacing: 8) {
                            Button("Open") { notchController.setExpanded(true, animated: true) }
                            Button("Close") { notchController.collapse() }
                            Button("Toggle") { notchController.toggleExpanded() }
                        }
                    }
                    .padding(8)
                }

                GroupBox("How to Close") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("↑ button · Esc · click the notch · move cursor away · menu bar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }

                GroupBox("Now Playing") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Source", value: musicController.sourceApp)
                        LabeledContent("Track", value: musicController.trackTitle)
                        LabeledContent("Artist", value: musicController.artistName)
                        Button("Refresh Music") {
                            musicController.refreshNowPlaying()
                        }
                    }
                    .padding(8)
                }

                GroupBox("Gestures") {
                    Text("3-finger swipe down opens the panel. Move your cursor away to close.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .padding(20)
        }
    }

    private var appearanceTab: some View {
        AppearanceSettingsView(appearance: appearanceStore)
            .padding(20)
    }
}
