import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class NotchWindowController: ObservableObject {
    @Published var isExpanded = false
    @Published var isVisible = true {
        didSet { updatePanelVisibility() }
    }

    var musicController: MusicController?
    var featureStore: NotchFeatureStore?
    var appearanceStore: NotchAppearanceStore?
    var stockController: StockController?
    var calendarController: CalendarController?
    var weatherController: WeatherController?
    var timerController: TimerStopwatchController?
    var sportsController: SportsController?
    var cryptoController: CryptoController?
    var newsController: NewsController?

    private var panel: NotchPanel?
    private var hostingView: NSHostingView<NotchContainerView>?
    private var geometry = NotchGeometry.primary()
    private var hoverTimer: Timer?
    private var hoverOpenTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var visibilityTimer: Timer?
    private var scrollMonitor: Any?
    private var keyMonitor: Any?
    private var collapseHoverTimer: Timer?
    private var hasVisitedWhileExpanded = false
    private var isHoveringNotchZone = false

    func show() {
        guard panel == nil else { return }

        featureStore?.onLayoutChange = { [weak self] in
            self?.refreshLayout()
        }
        featureStore?.onInteractionFocus = { [weak self] in
            self?.focusPanelForInteraction()
        }

        geometry = NotchGeometry.primary()
        let features = featureStore ?? NotchFeatureStore()

        let content = NotchContainerView(controller: self)
        let hosting = NSHostingView(rootView: content)
        hostingView = hosting

        let initialFrame = geometry.frame(forExpanded: false, features: features)
        let panel = NotchPanel(
            contentRect: initialFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false

        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor

            hosting.frame = contentView.bounds
            hosting.autoresizingMask = [.width, .height]
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = NSColor.clear.cgColor
            hosting.layer?.isOpaque = false
            contentView.addSubview(hosting)
        }

        self.panel = panel
        panel.orderFrontRegardless()

        NSLog("NotchControlCenter: panel shown at \(NSStringFromRect(initialFrame))")

        observeScreenChanges()
        startHoverTracking()
        startScrollMonitoring()
        startKeyboardMonitoring()
        startVisibilityKeepAlive()
    }

    func collapse(animated: Bool = true) {
        setExpanded(false, animated: animated)
    }

    func toggleExpanded() {
        setExpanded(!isExpanded, animated: true)
    }

    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        hoverOpenTimer?.invalidate()
        hoverOpenTimer = nil
        isHoveringNotchZone = false
        if expanded {
            hasVisitedWhileExpanded = false
            suppressHoverUntil = Date().addingTimeInterval(0.5)
            stockController?.setContentVisible(true)
            sportsController?.setContentVisible(true)
            HapticFeedback.playOpen()
        } else {
            cancelScheduledCollapse()
            hasVisitedWhileExpanded = false
            stockController?.setContentVisible(false)
            sportsController?.setContentVisible(false)
            featureStore?.showInlineSettings = false
            featureStore?.inlineSettingsPage = .widgets
            featureStore?.isHoveringPanelContent = false
            featureStore?.isHoveringInlineSettings = false
        }
        refreshLayout(animated: animated)
    }

    func refreshLayout(animated: Bool = true) {
        updateFrame(animated: animated)
        if featureStore?.showInlineSettings == true {
            focusPanelForInteraction()
        }
        panel?.orderFrontRegardless()
    }

    private func focusPanelForInteraction() {
        guard let panel else { return }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var suppressHoverUntil = Date.distantPast

    private func updateFrame(animated: Bool) {
        guard let panel else { return }
        geometry = NotchGeometry.primary()
        let features = featureStore ?? NotchFeatureStore()
        let target = geometry.frame(forExpanded: isExpanded, features: features)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.38
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
    }

    private func updatePanelVisibility() {
        guard let panel else { return }
        if isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func startVisibilityKeepAlive() {
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.panel?.orderFrontRegardless()
        }
        if let visibilityTimer {
            RunLoop.main.add(visibilityTimer, forMode: .common)
        }
    }

    private func startHoverTracking() {
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.evaluateHover()
        }

        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.evaluateHover()
        }
        if let hoverTimer {
            RunLoop.main.add(hoverTimer, forMode: .common)
        }
    }

    private func evaluateHover() {
        guard isVisible, Date() >= suppressHoverUntil else { return }

        let mouse = NSEvent.mouseLocation
        geometry = NotchGeometry.primary()

        if !isExpanded {
            evaluateNotchHoverOpen(mouse: mouse)
            return
        }

        guard let panel else { return }

        if featureStore?.isInteractionPinned == true {
            hasVisitedWhileExpanded = true
            cancelScheduledCollapse()
            return
        }

        let hit = panel.frame.insetBy(dx: -6, dy: -6)
        let inside = hit.contains(mouse)

        if inside {
            hasVisitedWhileExpanded = true
            cancelScheduledCollapse()
        } else if hasVisitedWhileExpanded {
            scheduleCollapseIfNeeded()
        }
    }

    private func scheduleCollapseIfNeeded() {
        guard collapseHoverTimer == nil else { return }
        collapseHoverTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.collapseHoverTimer = nil
            guard self.isExpanded, self.isVisible else { return }
            if self.featureStore?.isInteractionPinned == true { return }
            guard let panel = self.panel else { return }
            let mouse = NSEvent.mouseLocation
            if !panel.frame.insetBy(dx: -6, dy: -6).contains(mouse) {
                self.setExpanded(false, animated: true)
            }
        }
        if let collapseHoverTimer {
            RunLoop.main.add(collapseHoverTimer, forMode: .common)
        }
    }

    private func cancelScheduledCollapse() {
        collapseHoverTimer?.invalidate()
        collapseHoverTimer = nil
    }

    func collapseFromNotchTap() {
        guard isExpanded else { return }
        collapse()
    }

    private func startScrollMonitoring() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.isExpanded, self.isVisible, let panel = self.panel else { return event }
            let mouse = NSEvent.mouseLocation
            if panel.frame.insetBy(dx: -6, dy: -6).contains(mouse) {
                self.featureStore?.noteScrollInteraction()
                self.hasVisitedWhileExpanded = true
                self.cancelScheduledCollapse()
            }
            return event
        }
    }

    private func startKeyboardMonitoring() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isExpanded, self.isVisible else { return event }
            if event.keyCode == 53 {
                if self.featureStore?.showInlineSettings == true {
                    self.featureStore?.showInlineSettings = false
                    self.featureStore?.isHoveringInlineSettings = false
                    self.refreshLayout()
                } else {
                    self.collapse()
                }
                return nil
            }
            return event
        }
    }

    private func evaluateNotchHoverOpen(mouse: NSPoint) {
        let zone = geometry.notchHoverZone()
        let inZone = zone.contains(mouse)

        if inZone {
            if !isHoveringNotchZone {
                isHoveringNotchZone = true
                hoverOpenTimer?.invalidate()
                hoverOpenTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: false) { [weak self] _ in
                    guard let self, self.isVisible, !self.isExpanded else { return }
                    self.setExpanded(true, animated: true)
                }
                if let hoverOpenTimer {
                    RunLoop.main.add(hoverOpenTimer, forMode: .common)
                }
            }
        } else {
            isHoveringNotchZone = false
            hoverOpenTimer?.invalidate()
            hoverOpenTimer = nil
        }
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshLayout(animated: false)
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        hoverTimer?.invalidate()
        visibilityTimer?.invalidate()
        hoverOpenTimer?.invalidate()
        cancelScheduledCollapse()
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }
}

struct NotchContainerView: View {
    @ObservedObject var controller: NotchWindowController

    var body: some View {
        Group {
            if let music = controller.musicController,
               let features = controller.featureStore,
               let appearance = controller.appearanceStore,
               let stocks = controller.stockController,
               let calendar = controller.calendarController,
               let weather = controller.weatherController,
               let timer = controller.timerController,
               let sports = controller.sportsController,
               let crypto = controller.cryptoController,
               let news = controller.newsController {
                NotchView(isExpanded: controller.isExpanded)
                    .environmentObject(controller)
                    .environmentObject(appearance)
                    .environmentObject(music)
                    .environmentObject(features)
                    .environmentObject(stocks)
                    .environmentObject(calendar)
                    .environmentObject(weather)
                    .environmentObject(timer)
                    .environmentObject(sports)
                    .environmentObject(crypto)
                    .environmentObject(news)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.7))
            }
        }
    }
}
