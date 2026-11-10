import AppKit
import IPodCore

/// Playback controls shared by every music source.
protocol PlayerBackend: Sendable {
    /// Current player status. Throws `MusicError.notRunning` when the music app is closed.
    func status() async throws -> NowPlaying
    /// Artwork of the current track, `nil` when it has none.
    func artwork() async throws -> NSImage?
    func playPause() async throws
    func nextTrack() async throws
    func previousTrack() async throws
    func setVolume(_ volume: Int) async throws
    func toggleShuffle(from current: Bool) async throws
    func setRepeat(_ mode: RepeatMode, from current: RepeatMode) async throws
}

extension MusicController: PlayerBackend {
    func status() async throws -> NowPlaying {
        // Any `tell application "Music"` would launch Music, so check first.
        guard isRunning else { throw MusicError.notRunning }
        return try MusicParser.nowPlaying(try await text(MusicScripts.status))
    }

    func artwork() async throws -> NSImage? {
        do {
            return NSImage(data: try await data(MusicScripts.artwork))
        } catch MusicError.script {
            return nil  // track has no artwork
        }
    }

    func playPause() async throws { try await perform(MusicScripts.playPause) }
    func nextTrack() async throws { try await perform(MusicScripts.nextTrack) }
    func previousTrack() async throws { try await perform(MusicScripts.previousTrack) }
    func setVolume(_ volume: Int) async throws { try await perform(MusicScripts.setVolume(volume)) }
    func toggleShuffle(from current: Bool) async throws { try await perform(MusicScripts.setShuffle(!current)) }
    func setRepeat(_ mode: RepeatMode, from current: RepeatMode) async throws {
        try await perform(MusicScripts.setRepeat(mode))
    }
}
