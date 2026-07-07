import AppKit
import Foundation

enum MediaRemoteCommand: UInt32 {
    case pause = 2
    case play = 3
    case nextTrack = 4
    case previousTrack = 5
    case togglePlayPause = 6
}

struct NowPlayingSnapshot {
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    var elapsed: Double
    var duration: Double
    var sourceApp: String
    var artwork: NSImage?
}

final class MediaRemoteClient {
    static let shared = MediaRemoteClient()

    private typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
    private typealias GetPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (UInt32, CFDictionary?) -> Void

    private var registerNotifications: RegisterFn?
    private var getNowPlayingInfo: GetInfoFn?
    private var getIsPlaying: GetPlayingFn?
    private var sendCommand: SendCommandFn?

    private(set) var isAvailable = false

    private init() {
        loadFramework()
    }

    private func loadFramework() {
        guard let bundle = CFBundleCreate(
            kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework") as CFURL
        ) else { return }

        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) {
            registerNotifications = unsafeBitCast(ptr, to: RegisterFn.self)
        }
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            getNowPlayingInfo = unsafeBitCast(ptr, to: GetInfoFn.self)
        }
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) {
            getIsPlaying = unsafeBitCast(ptr, to: GetPlayingFn.self)
        }
        if let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            sendCommand = unsafeBitCast(ptr, to: SendCommandFn.self)
        }

        isAvailable = getNowPlayingInfo != nil
    }

    func startListening() {
        registerNotifications?(DispatchQueue.main)

        let names = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
        ]

        for name in names {
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { _ in
                NotificationCenter.default.post(name: .nowPlayingDidChange, object: nil)
            }
        }
    }

    func fetchNowPlaying(completion: @escaping (NowPlayingSnapshot?) -> Void) {
        // AppleScript is more reliable than MediaRemote on recent macOS versions.
        MusicMetadataFetcher.shared.fetch { [self] scriptSnapshot in
            if let scriptSnapshot {
                completion(scriptSnapshot)
                return
            }

            guard let getNowPlayingInfo else {
                completion(nil)
                return
            }

            getNowPlayingInfo(DispatchQueue.main) { cfInfo in
                let info = Self.normalizedDictionary(cfInfo)
                guard let snapshot = Self.parse(info) else {
                    completion(nil)
                    return
                }
                self.finishWithPlayingState(snapshot, completion: completion)
            }
        }
    }

    private func finishWithPlayingState(_ snapshot: NowPlayingSnapshot, completion: @escaping (NowPlayingSnapshot?) -> Void) {
        guard let getIsPlaying else {
            completion(snapshot)
            return
        }

        getIsPlaying(DispatchQueue.main) { playing in
            var updated = snapshot
            updated.isPlaying = playing
            completion(updated)
        }
    }

    private static func hasMetadata(_ snapshot: NowPlayingSnapshot) -> Bool {
        let title = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title != "Not Playing", title != "Now Playing" else { return false }
        return !snapshot.artist.isEmpty || snapshot.duration > 0
    }

    private static func normalizedDictionary(_ cfInfo: CFDictionary?) -> [String: Any] {
        guard let cfInfo else { return [:] }
        var result: [String: Any] = [:]
        let dict = cfInfo as NSDictionary
        for (key, value) in dict {
            let keyString: String
            if let stringKey = key as? String {
                keyString = stringKey
            } else {
                keyString = String(describing: key)
            }
            result[keyString] = value
        }
        return result
    }

    func send(_ command: MediaRemoteCommand) {
        if MusicMetadataFetcher.shared.sendTransport(command) {
            return
        }

        if let sendCommand {
            sendCommand(command.rawValue, nil)
            return
        }

        sendMediaKey(for: command)
    }

    func seek(to seconds: Double) {
        _ = MusicMetadataFetcher.shared.seek(to: seconds)
    }

    private func sendMediaKey(for command: MediaRemoteCommand) {
        let keyCode: CGKeyCode
        switch command {
        case .togglePlayPause, .play, .pause:
            keyCode = 0x31
        case .nextTrack:
            keyCode = 0x7E
        case .previousTrack:
            keyCode = 0x7D
        }

        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }

    private static func parse(_ info: [String: Any]) -> NowPlayingSnapshot? {
        let title = string(info, "kMRMediaRemoteNowPlayingInfoTitle")
            ?? string(info, "title")
            ?? ""
        let artist = string(info, "kMRMediaRemoteNowPlayingInfoArtist")
            ?? string(info, "artist") ?? ""
        let album = string(info, "kMRMediaRemoteNowPlayingInfoAlbum")
            ?? string(info, "album") ?? ""
        let duration = number(info, "kMRMediaRemoteNowPlayingInfoDuration")
            ?? number(info, "duration") ?? 0
        let elapsed = number(info, "kMRMediaRemoteNowPlayingInfoElapsedTime")
            ?? number(info, "elapsedTime") ?? 0
        let rate = number(info, "kMRMediaRemoteNowPlayingInfoPlaybackRate")
            ?? number(info, "playbackRate") ?? 0
        let app = string(info, "kMRMediaRemoteNowPlayingApplicationDisplayName")
            ?? string(info, "kMRMediaRemoteNowPlayingApplicationBundleIdentifier")
            ?? string(info, "bundleIdentifier")
            ?? "Now Playing"

        guard !title.isEmpty || !artist.isEmpty || duration > 0 else { return nil }

        var artwork: NSImage?
        if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
            artwork = NSImage(data: data)
        } else if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? NSData {
            artwork = NSImage(data: data as Data)
        }

        return NowPlayingSnapshot(
            title: title.isEmpty ? "Now Playing" : title,
            artist: artist,
            album: album,
            isPlaying: rate > 0,
            elapsed: elapsed,
            duration: duration,
            sourceApp: app,
            artwork: artwork
        )
    }

    private static func string(_ info: [String: Any], _ key: String) -> String? {
        if let value = info[key] as? String { return value }
        if let value = info[key] as? NSString { return value as String }
        return nil
    }

    private static func number(_ info: [String: Any], _ key: String) -> Double? {
        if let value = info[key] as? Double { return value }
        if let value = info[key] as? NSNumber { return value.doubleValue }
        return nil
    }
}

extension Notification.Name {
    static let nowPlayingDidChange = Notification.Name("NotchControlCenter.NowPlayingDidChange")
}
