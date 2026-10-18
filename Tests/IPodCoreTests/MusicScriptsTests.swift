import Testing
@testable import IPodCore

@Test func buildsPlayScriptForValidIDs() throws {
    let script = try MusicScripts.play(trackID: "0A1B2C3D4E5F6789", in: .playlist(id: "FFEE00"))
    #expect(script.contains(#"persistent ID is "0A1B2C3D4E5F6789""#))
    #expect(script.contains(#"user playlist whose persistent ID is "FFEE00""#))
}

@Test func rejectsInjectedIDs() {
    #expect(throws: MusicScriptError.invalidPersistentID(#"1" & quit"#)) {
        try MusicScripts.play(trackID: #"1" & quit"#, in: .library)
    }
}

@Test func clampsVolume() {
    #expect(MusicScripts.setVolume(150).hasSuffix("to 100"))
    #expect(MusicScripts.setVolume(-3).hasSuffix("to 0"))
}
