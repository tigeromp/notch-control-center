import AppKit
import Foundation

final class MusicMetadataFetcher {
    static let shared = MusicMetadataFetcher()

    private let musicBundleID = "com.apple.Music"
    private let spotifyBundleID = "com.spotify.client"

    func fetch(completion: @escaping (NowPlayingSnapshot?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let snapshot = fetchFromRunningApps()
            DispatchQueue.main.async {
                completion(snapshot)
            }
        }
    }

    @discardableResult
    func sendTransport(_ command: MediaRemoteCommand) -> Bool {
        if isRunning(musicBundleID), sendMusicTransport(command) { return true }
        if isRunning(spotifyBundleID), sendSpotifyTransport(command) { return true }
        return false
    }

    @discardableResult
    func seek(to seconds: Double) -> Bool {
        let position = max(0, seconds)
        if isRunning(musicBundleID), seekMusic(to: position) { return true }
        if isRunning(spotifyBundleID), seekSpotify(to: position) { return true }
        return false
    }

    private func seekMusic(to seconds: Double) -> Bool {
        executeScript("""
        tell application "Music"
            try
                set player position to \(seconds)
            end try
        end tell
        """)
    }

    private func seekSpotify(to seconds: Double) -> Bool {
        executeScript("""
        tell application "Spotify"
            try
                set player position to \(seconds)
            end try
        end tell
        """)
    }

    private func sendMusicTransport(_ command: MediaRemoteCommand) -> Bool {
        executeScript(musicTransportScript(for: command))
    }

    private func sendSpotifyTransport(_ command: MediaRemoteCommand) -> Bool {
        executeScript(spotifyTransportScript(for: command))
    }

    private func musicTransportScript(for command: MediaRemoteCommand) -> String {
        let action: String
        switch command {
        case .togglePlayPause: action = "playpause"
        case .play: action = "play"
        case .pause: action = "pause"
        case .nextTrack: action = "next track"
        case .previousTrack: action = "previous track"
        }
        return """
        tell application "Music"
            try
                \(action)
            end try
        end tell
        """
    }

    private func spotifyTransportScript(for command: MediaRemoteCommand) -> String {
        let action: String
        switch command {
        case .togglePlayPause: action = "playpause"
        case .play: action = "play"
        case .pause: action = "pause"
        case .nextTrack: action = "next track"
        case .previousTrack: action = "previous track"
        }
        return """
        tell application "Spotify"
            try
                \(action)
            end try
        end tell
        """
    }

    @discardableResult
    private func executeScript(_ source: String) -> Bool {
        var error: NSDictionary?
        _ = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("NotchControlCenter: transport AppleScript error: \(error)")
            return false
        }
        return true
    }

    private func fetchFromRunningApps() -> NowPlayingSnapshot? {
        // Prefer Music when both are open — check which is actually playing first.
        if isRunning(musicBundleID), isMusicPlaying(), let snapshot = fetchMusic() {
            return snapshot
        }
        if isRunning(spotifyBundleID), let snapshot = fetchSpotify() {
            return snapshot
        }
        if isRunning(musicBundleID), let snapshot = fetchMusic() {
            return snapshot
        }
        return nil
    }

    private func isRunning(_ bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    private func isMusicPlaying() -> Bool {
        guard let state = runScript(musicStateScript) else { return false }
        return state.lowercased().contains("play")
    }

    private func fetchMusic() -> NowPlayingSnapshot? {
        guard let payload = runScript(musicScript), !payload.isEmpty else { return nil }
        return parsePayload(payload, sourceApp: "Music", artwork: fetchMusicArtwork())
    }

    private func fetchSpotify() -> NowPlayingSnapshot? {
        guard let payload = runScript(spotifyScript), !payload.isEmpty else { return nil }
        guard var snapshot = parsePayload(payload, sourceApp: "Spotify", artwork: nil) else { return nil }
        if let urlString = payload.components(separatedBy: "|||").dropFirst(6).first,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            snapshot.artwork = fetchArtwork(from: url)
        }
        return snapshot
    }

    private func parsePayload(_ payload: String, sourceApp: String, artwork: NSImage?) -> NowPlayingSnapshot? {
        let parts = payload.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let artist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0
        let elapsed = Double(parts[4]) ?? 0
        let playState = parts[5]
        let isPlaying = playState.lowercased().contains("play") && !playState.lowercased().contains("pause")

        return NowPlayingSnapshot(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            elapsed: elapsed,
            duration: duration,
            sourceApp: sourceApp,
            artwork: artwork
        )
    }

    private func fetchMusicArtwork() -> NSImage? {
        guard let descriptor = runScriptDescriptor(musicArtworkScript) else { return nil }
        let data = descriptor.data
        guard !data.isEmpty else { return nil }
        return NSImage(data: data)
    }

    private func fetchArtwork(from url: URL) -> NSImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var image: NSImage?

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data {
                image = NSImage(data: data)
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 2.5)
        return image
    }

    private func runScript(_ source: String) -> String? {
        guard let descriptor = runScriptDescriptor(source) else { return nil }
        return descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runScriptDescriptor(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)
        if let error {
            NSLog("NotchControlCenter: AppleScript error: \(error)")
            return nil
        }
        return result
    }

    private var musicStateScript: String {
        """
        tell application "Music"
            try
                return player state as string
            on error
                return ""
            end try
        end tell
        """
    }

    private var musicScript: String {
        """
        tell application "Music"
            try
                if not (exists current track) then return ""
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                set trackPosition to player position
                set playState to player state as string
                return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as text) & "|||" & (trackPosition as text) & "|||" & playState
            on error errMsg
                return ""
            end try
        end tell
        """
    }

    private var spotifyScript: String {
        """
        tell application "Spotify"
            try
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                set trackPosition to player position
                set playState to player state as string
                set artURL to artwork url of current track
                return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as text) & "|||" & (trackPosition as text) & "|||" & playState & "|||" & artURL
            on error errMsg
                return ""
            end try
        end tell
        """
    }

    private var musicArtworkScript: String {
        """
        tell application "Music"
            try
                if (count of artworks of current track) is 0 then return missing value
                return raw data of artwork 1 of current track
            on error
                return missing value
            end try
        end tell
        """
    }
}
