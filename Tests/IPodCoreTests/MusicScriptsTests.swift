import Testing
@testable import IPodCore

@Test func playlistPlayStartsPlaylistAndSkipsToTrack() throws {
    let script = try MusicScripts.play(trackID: "0A1B2C3D4E5F6789", position: 8, in: .playlist(id: "FFEE00"))
    #expect(script.contains(#"user playlist whose persistent ID is "FFEE00""#))
    #expect(script.contains("play p"))
    #expect(script.contains("if true then set sound volume to 0"))
    #expect(script.contains(#"persistent ID of current track is "0A1B2C3D4E5F6789""#))
    #expect(script.contains("number \(MusicScripts.trackNotStartedError)"))
}

@Test func firstPlaylistTrackDoesNotMute() throws {
    let script = try MusicScripts.play(trackID: "AB", position: 1, in: .playlist(id: "CD"))
    #expect(script.contains("if false then set sound volume to 0"))
}

@Test func rejectsPositionBeforeFirstTrack() {
    #expect(throws: MusicScriptError.invalidPosition(0)) {
        try MusicScripts.play(trackID: "AB", position: 0, in: .playlist(id: "CD"))
    }
}

@Test func rejectsInjectedIDs() {
    #expect(throws: MusicScriptError.invalidPersistentID(#"1" & quit"#)) {
        try MusicScripts.play(trackID: #"1" & quit"#, position: 1, in: .library)
    }
}

@Test func clampsVolume() {
    #expect(MusicScripts.setVolume(150).hasSuffix("to 100"))
    #expect(MusicScripts.setVolume(-3).hasSuffix("to 0"))
}
