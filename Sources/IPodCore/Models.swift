import Foundation

/// Music.app playback state.
public enum PlayerState: String, Equatable, Sendable {
    case playing, paused, stopped
}

/// Music.app repeat mode, matching the AppleScript `song repeat` values.
public enum RepeatMode: String, Equatable, Sendable, CaseIterable {
    case off, one, all

    /// The next mode in the iPod cycle order (Off → One → All → Off).
    public var next: RepeatMode {
        switch self {
        case .off: return .one
        case .one: return .all
        case .all: return .off
        }
    }
}

/// Snapshot of the Music.app player.
public struct NowPlaying: Equatable, Sendable {
    public var state: PlayerState
    public var volume: Int
    public var shuffle: Bool
    public var repeatMode: RepeatMode
    /// Persistent ID of the current track, `nil` when nothing is loaded.
    public var trackID: String?
    public var title: String
    public var artist: String
    public var album: String
    public var position: Double
    public var duration: Double
    /// 1-based index of the current track in its playlist, if known.
    public var index: Int?
    public var count: Int?

    public init(
        state: PlayerState, volume: Int, shuffle: Bool, repeatMode: RepeatMode,
        trackID: String?, title: String, artist: String, album: String,
        position: Double, duration: Double, index: Int?, count: Int?
    ) {
        self.state = state
        self.volume = volume
        self.shuffle = shuffle
        self.repeatMode = repeatMode
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.album = album
        self.position = position
        self.duration = duration
        self.index = index
        self.count = count
    }
}

/// A track in the Music library.
public struct Track: Equatable, Sendable {
    public let id: String
    public let title: String
    public let artist: String

    public init(id: String, title: String, artist: String) {
        self.id = id
        self.title = title
        self.artist = artist
    }
}

/// A user playlist in the Music library.
public struct Playlist: Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Where a track is played from; decides what plays after it.
public enum Container: Equatable, Sendable {
    case library
    case playlist(id: String)
}
