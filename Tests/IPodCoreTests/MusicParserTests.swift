import Testing
@testable import IPodCore

private let fs = "\u{1F}", rs = "\u{1E}", gs = "\u{1D}"

@Test func parsesPlayingStatus() throws {
    let text = ["playing", "60", "true", "all", "ABC123", "Song", "Artist", "Album", "12,5", "200.0", "3", "12"]
        .joined(separator: fs)
    let np = try MusicParser.nowPlaying(text)
    #expect(np.state == .playing)
    #expect(np.shuffle)
    #expect(np.repeatMode == .all)
    #expect(np.trackID == "ABC123")
    #expect(np.position == 12.5)
    #expect(np.index == 3 && np.count == 12)
}

@Test func parsesStoppedStatusWithoutTrack() throws {
    let text = ["stopped", "40", "false", "off", "", "", "", "", "", "", "", ""].joined(separator: fs)
    let np = try MusicParser.nowPlaying(text)
    #expect(np.trackID == nil)
    #expect(np.duration == 0)
    #expect(np.index == nil)
}

@Test func rejectsStatusWithWrongFieldCount() {
    #expect(throws: MusicParseError.fieldCount(expected: 12, actual: 2)) {
        try MusicParser.nowPlaying("playing\(fs)60")
    }
}

@Test func parsesTrackColumnsIncludingEmptyFields() throws {
    let text = "A1\(rs)B2" + gs + "One\(rs)Two" + gs + "\(rs)Band"
    let tracks = try MusicParser.tracks(text)
    #expect(tracks == [Track(id: "A1", title: "One", artist: ""), Track(id: "B2", title: "Two", artist: "Band")])
}

@Test func parsesSingleTrackWithEmptyArtist() throws {
    #expect(try MusicParser.tracks("A1\(gs)One\(gs)") == [Track(id: "A1", title: "One", artist: "")])
}

@Test func parsesEmptyList() throws {
    #expect(try MusicParser.playlists(gs).isEmpty)
}

@Test func rejectsMismatchedColumns() {
    #expect(throws: MusicParseError.columnMismatch) {
        try MusicParser.playlists("A1\(rs)B2\(gs)Only one")
    }
}
