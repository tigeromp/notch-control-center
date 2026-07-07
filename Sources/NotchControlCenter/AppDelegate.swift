import AppKit
import ApplicationServices
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let notchController = NotchWindowController()
    let musicController = MusicController()
    let featureStore = NotchFeatureStore()
    let appearanceStore = NotchAppearanceStore()
    let stockController = StockController()
    let calendarController = CalendarController()
    let weatherController = WeatherController()
    let timerController = TimerStopwatchController()
    let sportsController = SportsController()
    let cryptoController = CryptoController()
    let newsController = NewsController()
    private let gestureMonitor = ThreeFingerGestureMonitor()

    private var statusItem: NSStatusItem?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        notchController.musicController = musicController
        notchController.featureStore = featureStore
        notchController.appearanceStore = appearanceStore
        notchController.stockController = stockController
        notchController.calendarController = calendarController
        notchController.weatherController = weatherController
        notchController.timerController = timerController
        notchController.sportsController = sportsController
        notchController.cryptoController = cryptoController
        notchController.newsController = newsController
        newsController.bind(to: weatherController)
        sportsController.onLayoutChange = { [weak self] in
            self?.notchController.refreshLayout()
        }
        notchController.show()

        if CommandLine.arguments.contains("--demo-expand") {
            featureStore.stocksEnabled = true
            featureStore.sportsEnabled = true
            featureStore.musicEnabled = true
            featureStore.weatherEnabled = true
            featureStore.newsEnabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.notchController.setExpanded(true, animated: true)
            }
        }

        gestureMonitor.notchController = notchController
        requestAccessibilityIfNeeded()
        gestureMonitor.start()

        setupMenuBar()
        musicController.startMonitoring()
        stockController.startMonitoring()
        calendarController.startMonitoring()
        weatherController.startMonitoring()
        timerController.startMonitoring()
        sportsController.startMonitoring()
        cryptoController.startMonitoring()
        newsController.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        gestureMonitor.stop()
        musicController.stopMonitoring()
        stockController.stopMonitoring()
        calendarController.stopMonitoring()
        weatherController.stopMonitoring()
        timerController.stopMonitoring()
        sportsController.stopMonitoring()
        cryptoController.stopMonitoring()
        newsController.stopMonitoring()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "music.note.house.fill", accessibilityDescription: "Notch Control Center")
            button.action = #selector(toggleNotch)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Notch Panel", action: #selector(toggleNotch), keyEquivalent: "n")
        menu.addItem(withTitle: "Collapse Notch Panel", action: #selector(closeNotch), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Notch Control Center", action: #selector(quit), keyEquivalent: "q")

        statusItem?.menu = menu
    }

    @objc private func toggleNotch() {
        notchController.toggleExpanded()
    }

    @objc private func closeNotch() {
        notchController.collapse()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func requestAccessibilityIfNeeded() {
        // Only check — do not prompt on every launch (prompt blocks and annoys users).
        _ = AXIsProcessTrusted()
    }
}
