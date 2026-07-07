import AppKit
import CoreGraphics

struct NotchGeometry {
    let screen: NSScreen
    let hasNotch: Bool
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let safeAreaTop: CGFloat
    let menuBarHeight: CGFloat

    static func primary() -> NotchGeometry {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        return NotchGeometry(screen: screen)
    }

    init(screen: NSScreen) {
        self.screen = screen
        menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY

        if #available(macOS 12.0, *) {
            let left = screen.auxiliaryTopLeftArea?.width ?? 0
            let right = screen.auxiliaryTopRightArea?.width ?? 0
            hasNotch = left > 0 || right > 0
            let cutout = max(screen.frame.width - left - right, 0)
            notchWidth = hasNotch ? cutout : 220
            safeAreaTop = screen.safeAreaInsets.top
            notchHeight = max(safeAreaTop, menuBarHeight)
        } else {
            hasNotch = false
            notchWidth = 220
            notchHeight = 28
            safeAreaTop = 0
        }
    }

    var collapsedSize: CGSize {
        collapsedSize(for: NotchFeatureStore())
    }

    func collapsedSize(for features: NotchFeatureStore) -> CGSize {
        let width: CGFloat = hasNotch ? min(max(notchWidth - 8, 90), 140) : 112
        let height: CGFloat = hasNotch ? max(menuBarHeight, 26) : 22
        return CGSize(width: width, height: height)
    }

    var expandedTopInset: CGFloat {
        hasNotch ? max(safeAreaTop * 0.35, 10) : 8
    }

    func notchHoverZone() -> CGRect {
        let screenFrame = screen.frame
        let width = max(notchWidth + 48, collapsedSize.width + 24)
        let height = max(notchHeight + 20, collapsedSize.height + 12)
        let x = screenFrame.midX - (width / 2)
        let y = screenFrame.maxY - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func expandedSize(for features: NotchFeatureStore) -> CGSize {
        let width = min(480, screen.frame.width * 0.44)
        let topInset = expandedTopInset

        if features.showInlineSettings {
            let settingsHeight: CGFloat = features.inlineSettingsPage == .appearance ? 460 : 430
            return CGSize(width: width, height: topInset + settingsHeight)
        }

        var height = topInset + 20 + min(features.expandedModulesHeight, 380)
        if !features.hasAnyWidgetEnabled { height += 36 }
        return CGSize(width: width, height: max(height, topInset + 56))
    }

    func frame(forExpanded expanded: Bool, features: NotchFeatureStore) -> CGRect {
        let size = expanded ? expandedSize(for: features) : collapsedSize(for: features)
        let frame = screen.frame
        let x = frame.midX - (size.width / 2)
        let y = frame.maxY - size.height
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}

extension NotchFeatureStore {
    var expandedModulesHeight: CGFloat {
        var height: CGFloat = 0
        if musicEnabled { height += 68 }
        if timerEnabled { height += 76 }
        if meetingModeEnabled { height += 52 }
        if stocksEnabled { height += 34 }
        if cryptoEnabled { height += 34 }
        if sportsEnabled {
            height += 36
        }
        if newsEnabled { height += 34 }
        if calendarEnabled { height += 56 }
        if weatherEnabled { height += 36 }
        return height
    }
}
