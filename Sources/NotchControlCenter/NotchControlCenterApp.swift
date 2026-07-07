import SwiftUI

@main
struct NotchControlCenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.notchController)
                .environmentObject(appDelegate.musicController)
                .environmentObject(appDelegate.featureStore)
                .environmentObject(appDelegate.appearanceStore)
                .environmentObject(appDelegate.stockController)
        }
    }
}
