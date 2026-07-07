import AppKit
import Combine
import CoreGraphics
import Foundation

final class MusicController: ObservableObject {
    @Published var trackTitle = "Not Playing"
    @Published var artistName = ""
    @Published var albumName = ""
    @Published var isPlaying = false
    @Published var artwork: NSImage?
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var sourceApp = "None"

    private var timer: Timer?
    private var progressAnchor = Date()
    private var progressAnchorValue: Double = 0
    private var isScrubbing = false
    private let mediaRemote = MediaRemoteClient.shared

    func startMonitoring() {
        mediaRemote.startListening()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingChanged),
            name: .nowPlayingDidChange,
            object: nil
        )

        refreshNowPlaying()
        startProgressTimer()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
    }

    private func startProgressTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshNowPlaying()
            self?.tickProgress()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @objc private func nowPlayingChanged() {
        refreshNowPlaying()
    }

    func refreshNowPlaying() {
        mediaRemote.fetchNowPlaying { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.apply(snapshot)
            }
        }
    }

    private func apply(_ snapshot: NowPlayingSnapshot?) {
        guard let snapshot else { return }

        trackTitle = snapshot.title
        artistName = snapshot.artist
        albumName = snapshot.album
        isPlaying = snapshot.isPlaying
        if let snapshotArtwork = snapshot.artwork {
            artwork = snapshotArtwork
        }
        if !isScrubbing {
            progress = snapshot.elapsed
            progressAnchor = Date()
            progressAnchorValue = snapshot.elapsed
        }
        duration = snapshot.duration
        sourceApp = snapshot.sourceApp
    }

    private func tickProgress() {
        guard isPlaying, duration > 0, !isScrubbing else { return }
        let elapsed = Date().timeIntervalSince(progressAnchor)
        progress = min(progressAnchorValue + elapsed, duration)
    }

    func togglePlayPause() {
        mediaRemote.send(.togglePlayPause)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.refreshNowPlaying() }
    }

    func nextTrack() {
        mediaRemote.send(.nextTrack)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.refreshNowPlaying() }
    }

    func previousTrack() {
        mediaRemote.send(.previousTrack)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.refreshNowPlaying() }
    }

    func setScrubbing(_ scrubbing: Bool) {
        isScrubbing = scrubbing
        if !scrubbing {
            progressAnchor = Date()
            progressAnchorValue = progress
        }
    }

    func seek(to value: Double) {
        let clamped = min(max(value, 0), max(duration, 0))
        progress = clamped
        progressAnchor = Date()
        progressAnchorValue = clamped
        mediaRemote.seek(to: clamped)
    }
}
