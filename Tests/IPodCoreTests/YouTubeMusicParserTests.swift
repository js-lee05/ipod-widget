import Foundation
import Testing
@testable import IPodCore

private func json(_ s: String) -> Data { Data(s.utf8) }

private let volume = json(#"{"state": 42.4, "isMuted": false}"#)
private let shuffle = json(#"{"state": true}"#)
private let repeatAll = json(#"{"mode": "ALL"}"#)

@Test func parsesPlayingSong() throws {
    let song = json("""
        {"title": "Song", "artist": "Artist", "views": 10, "album": null,
         "imageSrc": "https://example.com/a.jpg", "isPaused": false, "songDuration": 200,
         "elapsedSeconds": 12, "videoId": "abc_-123", "mediaType": "AUDIO"}
        """)
    let status = try YouTubeMusicParser.status(song: song, volume: volume, shuffle: shuffle, repeatMode: repeatAll)
    let np = status.nowPlaying
    #expect(np.state == .playing)
    #expect(np.trackID == "abc_-123")
    #expect(np.album == "")
    #expect(np.position == 12 && np.duration == 200)
    #expect(np.volume == 42)
    #expect(np.shuffle)
    #expect(np.repeatMode == .all)
    #expect(np.index == nil)
    #expect(status.artworkURL == URL(string: "https://example.com/a.jpg"))
}

@Test func parsesNoSongAsStopped() throws {
    let status = try YouTubeMusicParser.status(
        song: nil, volume: volume, shuffle: json(#"{"state": null}"#), repeatMode: json(#"{"mode": null}"#))
    #expect(status.nowPlaying.state == .stopped)
    #expect(status.nowPlaying.trackID == nil)
    #expect(status.nowPlaying.shuffle == false)
    #expect(status.nowPlaying.repeatMode == .off)
    #expect(status.artworkURL == nil)
}

@Test func rejectsSongWithoutVideoID() {
    #expect(throws: DecodingError.self) {
        try YouTubeMusicParser.status(
            song: json(#"{"title": "x", "artist": "y", "songDuration": 1}"#),
            volume: volume, shuffle: shuffle, repeatMode: repeatAll)
    }
}

@Test func parsesQueueWithPlainAndWrappedItems() throws {
    let queue = json("""
        {"items": [
          {"playlistPanelVideoRenderer": {"videoId": "A", "title": {"runs": [{"text": "One"}]},
            "shortBylineText": {"runs": [{"text": "Band"}]}, "selected": false}},
          {"playlistPanelVideoWrapperRenderer": {"primaryRenderer": {"playlistPanelVideoRenderer":
            {"videoId": "B", "title": {"runs": [{"text": "Tw"}, {"text": "o"}]}, "selected": true}}}},
          {"automixPreviewVideoRenderer": {}}
        ]}
        """)
    #expect(try YouTubeMusicParser.queue(queue) == [
        QueueItem(videoID: "A", title: "One", artist: "Band", isCurrent: false),
        QueueItem(videoID: "B", title: "Two", artist: "", isCurrent: true),
    ])
}

@Test func parsesQueueWithoutItemsAsEmpty() throws {
    #expect(try YouTubeMusicParser.queue(json("{}")).isEmpty)
}

@Test func rejectsQueueThatIsNotJSON() {
    #expect(throws: DecodingError.self) { try YouTubeMusicParser.queue(json("<html>")) }
}

@Test func countsRepeatPressesAlongYouTubeCycle() {
    // YouTube Music cycles Off → All → One.
    #expect(YouTubeMusicParser.repeatPresses(from: .off, to: .all) == 1)
    #expect(YouTubeMusicParser.repeatPresses(from: .off, to: .one) == 2)
    #expect(YouTubeMusicParser.repeatPresses(from: .all, to: .off) == 2)
    #expect(YouTubeMusicParser.repeatPresses(from: .one, to: .one) == 0)
}
