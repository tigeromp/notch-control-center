import Foundation

enum ClockMode: String, CaseIterable {
    case timer
    case stopwatch
}

final class TimerStopwatchController: ObservableObject {
    @Published var mode: ClockMode = .timer
    @Published var timerRemaining: TimeInterval = 0
    @Published var timerTotal: TimeInterval = 0
    @Published var timerRunning = false
    @Published var stopwatchElapsed: TimeInterval = 0
    @Published var stopwatchRunning = false
    @Published var timerFinished = false

    private var tickTimer: Timer?
    private var lastTick = Date()

    func startMonitoring() {
        startTicking()
    }

    func stopMonitoring() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func startTicking() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let tickTimer {
            RunLoop.main.add(tickTimer, forMode: .common)
        }
        lastTick = Date()
    }

    private func tick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastTick)
        lastTick = now

        if timerRunning, timerRemaining > 0 {
            timerRemaining = max(0, timerRemaining - delta)
            if timerRemaining == 0 {
                timerRunning = false
                timerFinished = true
                HapticFeedback.playTimerDone()
            }
        }

        if stopwatchRunning {
            stopwatchElapsed += delta
        }
    }

    func startTimer(minutes: Int) {
        startTimer(seconds: TimeInterval(minutes * 60))
    }

    func startTimer(seconds: TimeInterval) {
        let clamped = max(1, min(seconds, 24 * 3600))
        timerTotal = clamped
        timerRemaining = clamped
        timerRunning = true
        timerFinished = false
        mode = .timer
    }

    @discardableResult
    func startTimer(from input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":").map(String.init)
            guard parts.count == 2,
                  let minutes = Int(parts[0]),
                  let seconds = Int(parts[1]),
                  minutes >= 0, seconds >= 0, seconds < 60,
                  minutes > 0 || seconds > 0 else { return false }
            startTimer(seconds: TimeInterval(minutes * 60 + seconds))
            return true
        }

        if let minutes = Int(trimmed), minutes > 0 {
            startTimer(minutes: minutes)
            return true
        }

        return false
    }

    func pauseTimer() {
        timerRunning = false
    }

    func resumeTimer() {
        guard timerRemaining > 0 else { return }
        timerRunning = true
        timerFinished = false
    }

    func resetTimer() {
        timerRunning = false
        timerRemaining = 0
        timerTotal = 0
        timerFinished = false
    }

    func toggleTimer() {
        timerRunning ? pauseTimer() : resumeTimer()
    }

    func startStopwatch() {
        stopwatchRunning = true
        mode = .stopwatch
    }

    func pauseStopwatch() {
        stopwatchRunning = false
    }

    func resetStopwatch() {
        stopwatchRunning = false
        stopwatchElapsed = 0
    }

    func toggleStopwatch() {
        stopwatchRunning ? pauseStopwatch() : startStopwatch()
    }

    var timerProgress: Double {
        guard timerTotal > 0 else { return 0 }
        return 1 - (timerRemaining / timerTotal)
    }

    func formattedTimerRemaining() -> String {
        formatInterval(timerRemaining)
    }

    func formattedStopwatchElapsed() -> String {
        formatInterval(stopwatchElapsed)
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
