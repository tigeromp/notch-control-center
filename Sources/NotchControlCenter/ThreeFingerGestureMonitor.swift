import AppKit
import CoreFoundation
import Foundation

private enum MTTouchState: UInt32 {
    case notTracking = 0
    case startInRange = 1
    case hoverInRange = 2
    case makeTouch = 3
    case touching = 4
    case breakTouch = 5
    case lingerInRange = 6
    case outOfRange = 7
}

private struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

private struct MTPoint {
    var x: Float
    var y: Float
}

private struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: MTTouchState
    var fingerID: Int32
    var handID: Int32
    var normalizedVector: MTVector
    var zTotal: Float
    var field9: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTVector
    var field14: Int32
    var field15: Int32
    var zDensity: Float
}

private typealias MTDeviceRef = UnsafeMutableRawPointer
private typealias MTFrameCallback = @convention(c) (
    MTDeviceRef,
    UnsafeMutableRawPointer,
    Int,
    Double,
    Int
) -> Void

private typealias MTDeviceCreateListFn = @convention(c) () -> CFArray?
private typealias MTDeviceCreateDefaultFn = @convention(c) () -> MTDeviceRef?
private typealias MTDeviceIsBuiltInFn = @convention(c) (MTDeviceRef) -> Bool
private typealias MTRegisterContactFrameCallbackFn = @convention(c) (MTDeviceRef, MTFrameCallback) -> Void
private typealias MTDeviceStartFn = @convention(c) (MTDeviceRef, Int32) -> Int32
private typealias MTDeviceStopFn = @convention(c) (MTDeviceRef) -> Int32

private var activeGestureMonitor: ThreeFingerGestureMonitor?

private func mtContactFrameCallback(
    _: MTDeviceRef,
    rawTouches: UnsafeMutableRawPointer,
    count: Int,
    _: Double,
    _: Int
) {
    if count == 0 {
        activeGestureMonitor?.handleAllTouchesLifted()
        return
    }

    let touches = rawTouches.assumingMemoryBound(to: MTTouch.self)
    activeGestureMonitor?.handleTouches(touches: touches, count: count)
}

/// 3-finger swipe down opens the panel. Close is handled by moving the cursor away.
final class ThreeFingerGestureMonitor {
    weak var notchController: NotchWindowController?

    private var devices: [MTDeviceRef] = []
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var isRunning = false

    private var openSessionActive = false
    private var openPeakFingerCount = 0
    private var openStartY: Float = 0
    private var openCurrentY: Float = 0

    private var lastTriggerTime = Date.distantPast

    private let swipeThreshold: Float = 0.07
    private let cooldown: TimeInterval = 0.45

    func start() {
        guard !isRunning else { return }

        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        frameworkHandle = dlopen(path, RTLD_LAZY)
        guard let handle = frameworkHandle else {
            NSLog("NotchControlCenter: MultitouchSupport unavailable")
            return
        }

        guard
            let registerPtr = dlsym(handle, "MTRegisterContactFrameCallback"),
            let startPtr = dlsym(handle, "MTDeviceStart")
        else {
            NSLog("NotchControlCenter: MultitouchSupport symbols missing")
            return
        }

        let register = unsafeBitCast(registerPtr, to: MTRegisterContactFrameCallbackFn.self)
        let startDevice = unsafeBitCast(startPtr, to: MTDeviceStartFn.self)

        activeGestureMonitor = self
        var startedCount = 0

        if let listPtr = dlsym(handle, "MTDeviceCreateList") {
            let createList = unsafeBitCast(listPtr, to: MTDeviceCreateListFn.self)
            if let list = createList() {
                let count = CFArrayGetCount(list)
                let isBuiltInFn: MTDeviceIsBuiltInFn? = {
                    guard let ptr = dlsym(handle, "MTDeviceIsBuiltIn") else { return nil }
                    return unsafeBitCast(ptr, to: MTDeviceIsBuiltInFn.self)
                }()

                for index in 0..<count {
                    guard let value = CFArrayGetValueAtIndex(list, index) else { continue }
                    let device = UnsafeMutableRawPointer(mutating: value)

                    if let isBuiltInFn, !isBuiltInFn(device) {
                        continue
                    }

                    register(device, mtContactFrameCallback)
                    _ = startDevice(device, 0)
                    devices.append(device)
                    startedCount += 1
                }
            }
        }

        if startedCount == 0, let createDefaultPtr = dlsym(handle, "MTDeviceCreateDefault") {
            let createDefault = unsafeBitCast(createDefaultPtr, to: MTDeviceCreateDefaultFn.self)
            if let device = createDefault() {
                register(device, mtContactFrameCallback)
                _ = startDevice(device, 0)
                devices.append(device)
                startedCount = 1
            }
        }

        guard startedCount > 0 else {
            NSLog("NotchControlCenter: no trackpad devices found")
            return
        }

        isRunning = true
        NSLog("NotchControlCenter: gesture monitor started on \(startedCount) device(s)")
    }

    func stop() {
        guard isRunning, let handle = frameworkHandle else { return }

        if let stopPtr = dlsym(handle, "MTDeviceStop") {
            let stop = unsafeBitCast(stopPtr, to: MTDeviceStopFn.self)
            for device in devices {
                _ = stop(device)
            }
        }

        devices.removeAll()
        if activeGestureMonitor === self {
            activeGestureMonitor = nil
        }
        isRunning = false
    }

    fileprivate func handleAllTouchesLifted() {
        finishOpenSession()
    }

    fileprivate func handleTouches(touches: UnsafeMutablePointer<MTTouch>, count: Int) {
        let activeIndices = (0..<count).filter { isActiveTouch(touches[$0].state) }
        let fingerCount = activeIndices.count

        guard fingerCount == 3 else {
            cancelOpenSession()
            return
        }

        guard notchController?.isExpanded != true else {
            cancelOpenSession()
            return
        }

        let averageY = activeIndices.reduce(Float(0)) { sum, index in
            sum + touches[index].normalizedVector.position.y
        } / Float(fingerCount)

        trackOpenSession(fingerCount: fingerCount, averageY: averageY)
        evaluateOpenSwipeIfNeeded()
    }

    private func isActiveTouch(_ state: MTTouchState) -> Bool {
        switch state {
        case .startInRange, .hoverInRange, .makeTouch, .touching:
            return true
        default:
            return false
        }
    }

    private func trackOpenSession(fingerCount: Int, averageY: Float) {
        if !openSessionActive {
            openSessionActive = true
            openPeakFingerCount = fingerCount
            openStartY = averageY
            openCurrentY = averageY
        } else {
            openPeakFingerCount = max(openPeakFingerCount, fingerCount)
            openCurrentY = averageY
        }
    }

    private func evaluateOpenSwipeIfNeeded() {
        guard openSessionActive, openPeakFingerCount == 3 else { return }
        guard notchController?.isExpanded == false else { return }
        guard Date().timeIntervalSince(lastTriggerTime) > cooldown else { return }

        let deltaY = openCurrentY - openStartY

        // Swipe down (away from the screen) opens the panel.
        if deltaY < -swipeThreshold {
            triggerOpen()
            cancelOpenSession()
        }
    }

    private func finishOpenSession() {
        evaluateOpenSwipeIfNeeded()
        cancelOpenSession()
    }

    private func triggerOpen() {
        lastTriggerTime = Date()
        DispatchQueue.main.async { [weak self] in
            self?.notchController?.setExpanded(true, animated: true)
        }
    }

    private func cancelOpenSession() {
        openSessionActive = false
        openPeakFingerCount = 0
    }

    deinit {
        stop()
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }
}
