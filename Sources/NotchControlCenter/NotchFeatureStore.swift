import Combine
import Foundation

enum InlineSettingsPage {
    case widgets
    case appearance
}

final class NotchFeatureStore: ObservableObject {
    @Published var musicEnabled: Bool {
        didSet { UserDefaults.standard.set(musicEnabled, forKey: Keys.music) }
    }
    @Published var stocksEnabled: Bool {
        didSet { UserDefaults.standard.set(stocksEnabled, forKey: Keys.stocks) }
    }
    @Published var calendarEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarEnabled, forKey: Keys.calendar) }
    }
    @Published var weatherEnabled: Bool {
        didSet { UserDefaults.standard.set(weatherEnabled, forKey: Keys.weather) }
    }
    @Published var timerEnabled: Bool {
        didSet { UserDefaults.standard.set(timerEnabled, forKey: Keys.timer) }
    }
    @Published var meetingModeEnabled: Bool {
        didSet { UserDefaults.standard.set(meetingModeEnabled, forKey: Keys.meeting) }
    }
    @Published var sportsEnabled: Bool {
        didSet { UserDefaults.standard.set(sportsEnabled, forKey: Keys.sports) }
    }
    @Published var cryptoEnabled: Bool {
        didSet { UserDefaults.standard.set(cryptoEnabled, forKey: Keys.crypto) }
    }
    @Published var newsEnabled: Bool {
        didSet { UserDefaults.standard.set(newsEnabled, forKey: Keys.news) }
    }
    @Published var showInlineSettings = false
    @Published var inlineSettingsPage: InlineSettingsPage = .widgets
    @Published var isHoveringInlineSettings = false
    @Published var isHoveringPanelContent = false

    private var scrollPinnedUntil = Date.distantPast

    var isSettingsPinned: Bool {
        showInlineSettings || isHoveringInlineSettings
    }

    var isInteractionPinned: Bool {
        isSettingsPinned || isHoveringPanelContent || Date() < scrollPinnedUntil
    }

    func noteScrollInteraction() {
        scrollPinnedUntil = Date().addingTimeInterval(2.0)
    }

    var onLayoutChange: (() -> Void)?
    var onInteractionFocus: (() -> Void)?

    private enum Keys {
        static let music = "feature.music"
        static let stocks = "feature.stocks"
        static let calendar = "feature.calendar"
        static let weather = "feature.weather"
        static let timer = "feature.timer"
        static let meeting = "feature.meeting"
        static let sports = "feature.sports"
        static let crypto = "feature.crypto"
        static let news = "feature.news"
    }

    init() {
        let defaults = UserDefaults.standard
        musicEnabled = defaults.object(forKey: Keys.music) as? Bool ?? true
        stocksEnabled = defaults.object(forKey: Keys.stocks) as? Bool ?? false
        calendarEnabled = defaults.object(forKey: Keys.calendar) as? Bool ?? false
        weatherEnabled = defaults.object(forKey: Keys.weather) as? Bool ?? false
        timerEnabled = defaults.object(forKey: Keys.timer) as? Bool ?? false
        meetingModeEnabled = defaults.object(forKey: Keys.meeting) as? Bool ?? false
        sportsEnabled = defaults.object(forKey: Keys.sports) as? Bool ?? false
        cryptoEnabled = defaults.object(forKey: Keys.crypto) as? Bool ?? false
        newsEnabled = defaults.object(forKey: Keys.news) as? Bool ?? false
    }

    var hasAnyWidgetEnabled: Bool {
        musicEnabled || stocksEnabled || calendarEnabled || weatherEnabled
            || timerEnabled || meetingModeEnabled || sportsEnabled || cryptoEnabled || newsEnabled
    }

    func toggleInlineSettings() {
        showInlineSettings.toggle()
        if showInlineSettings {
            isHoveringPanelContent = false
        } else {
            isHoveringInlineSettings = false
            inlineSettingsPage = .widgets
        }
        onLayoutChange?()
        if showInlineSettings {
            onInteractionFocus?()
        }
    }

    func openAppearanceSettings() {
        showInlineSettings = true
        inlineSettingsPage = .appearance
        isHoveringPanelContent = false
        onLayoutChange?()
        onInteractionFocus?()
    }

    func backToWidgetSettings() {
        inlineSettingsPage = .widgets
        onLayoutChange?()
        onInteractionFocus?()
    }
}
