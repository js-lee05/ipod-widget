import Foundation

/// The music app the widget controls.
public enum MusicSource: String, CaseIterable, Sendable {
    case appleMusic, youtubeMusic

    public var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .youtubeMusic: return "YouTube Music"
        }
    }
}

/// A track in the YouTube Music play queue.
public struct QueueItem: Equatable, Sendable {
    public let videoID: String
    public let title: String
    public let artist: String
    /// Whether this is the track currently loaded in the player.
    public let isCurrent: Bool

    public init(videoID: String, title: String, artist: String, isCurrent: Bool) {
        self.videoID = videoID
        self.title = title
        self.artist = artist
        self.isCurrent = isCurrent
    }
}

/// Player status from the YouTube Music desktop app plus where to fetch the artwork.
public struct YouTubeMusicStatus: Equatable, Sendable {
    public var nowPlaying: NowPlaying
    public var artworkURL: URL?
}

/// Parses responses of the YouTube Music desktop app's API Server plugin (`/api/v1`).
public enum YouTubeMusicParser {
    /// YouTube Music's repeat button order, which `/switch-repeat` steps through.
    private static let repeatCycle: [RepeatMode] = [.off, .all, .one]

    private struct Song: Decodable {
        let title: String
        let artist: String
        let album: String?
        let imageSrc: String?
        let isPaused: Bool?
        let songDuration: Double
        let elapsedSeconds: Double?
        let videoId: String
    }

    private struct Volume: Decodable { let state: Double }
    private struct Shuffle: Decodable { let state: Bool? }
    private struct Repeat: Decodable { let mode: String? }

    private struct Queue: Decodable { let items: [Item]? }
    private struct Item: Decodable {
        let playlistPanelVideoRenderer: Renderer?
        let playlistPanelVideoWrapperRenderer: Wrapper?
    }
    private struct Wrapper: Decodable { let primaryRenderer: Primary? }
    private struct Primary: Decodable { let playlistPanelVideoRenderer: Renderer? }
    private struct Renderer: Decodable {
        let videoId: String?
        let title: Text?
        let shortBylineText: Text?
        let selected: Bool?
    }
    private struct Text: Decodable {
        struct Run: Decodable { let text: String }
        let runs: [Run]?
        var joined: String { (runs ?? []).map(\.text).joined() }
    }

    /// Combines `/song` (nil when it returned 204), `/volume`, `/shuffle` and `/repeat-mode` bodies.
    public static func status(song: Data?, volume: Data, shuffle: Data, repeatMode: Data) throws -> YouTubeMusicStatus {
        let decoder = JSONDecoder()
        let vol = try decoder.decode(Volume.self, from: volume)
        let sh = try decoder.decode(Shuffle.self, from: shuffle)
        let rp = try decoder.decode(Repeat.self, from: repeatMode)
        var nowPlaying = NowPlaying(
            state: .stopped, volume: Int(vol.state.rounded()), shuffle: sh.state ?? false,
            repeatMode: parseRepeat(rp.mode), trackID: nil, title: "", artist: "", album: "",
            position: 0, duration: 0, index: nil, count: nil
        )
        guard let song else { return YouTubeMusicStatus(nowPlaying: nowPlaying, artworkURL: nil) }
        let s = try decoder.decode(Song.self, from: song)
        nowPlaying.state = s.isPaused == true ? .paused : .playing
        nowPlaying.trackID = s.videoId
        nowPlaying.title = s.title
        nowPlaying.artist = s.artist
        nowPlaying.album = s.album ?? ""
        nowPlaying.position = s.elapsedSeconds ?? 0
        nowPlaying.duration = s.songDuration
        return YouTubeMusicStatus(nowPlaying: nowPlaying, artworkURL: s.imageSrc.flatMap(URL.init(string:)))
    }

    /// Parses `/queue`. Items without a video id (e.g. section headers) are skipped.
    public static func queue(_ data: Data) throws -> [QueueItem] {
        let queue = try JSONDecoder().decode(Queue.self, from: data)
        return (queue.items ?? []).compactMap { item in
            let renderer = item.playlistPanelVideoRenderer
                ?? item.playlistPanelVideoWrapperRenderer?.primaryRenderer?.playlistPanelVideoRenderer
            guard let renderer, let id = renderer.videoId else { return nil }
            return QueueItem(
                videoID: id,
                title: renderer.title?.joined ?? "",
                artist: renderer.shortBylineText?.joined ?? "",
                isCurrent: renderer.selected ?? false
            )
        }
    }

    /// Repeat-button presses needed to go from `current` to `target`.
    public static func repeatPresses(from current: RepeatMode, to target: RepeatMode) -> Int {
        let from = repeatCycle.firstIndex(of: current) ?? 0
        let to = repeatCycle.firstIndex(of: target) ?? 0
        return (to - from + repeatCycle.count) % repeatCycle.count
    }

    private static func parseRepeat(_ mode: String?) -> RepeatMode {
        switch mode {
        case "ONE": return .one
        case "ALL": return .all
        default: return .off
        }
    }
}
