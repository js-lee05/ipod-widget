import Foundation

/// Raised when a value would be unsafe to embed in AppleScript source.
public enum MusicScriptError: Error, Equatable {
    case invalidPersistentID(String)
    case invalidPosition(Int)
}

/// AppleScript sources that drive Music.app. Output formats match `MusicParser`.
public enum MusicScripts {
    private static let maxPersistentIDLength = 32
    private static let volumeRange = 0...100
    /// Polls (0.25 s each) to wait for a streamed track to start before giving up on it.
    private static let startPolls = 40

    /// Error number raised when the requested track did not end up playing.
    public static let trackNotStartedError = 9001

    /// Player status: 12 fields joined by ASCII 31. Track fields are empty when stopped.
    public static let status = """
        tell application "Music"
            set fs to character id 31
            set pst to player state as text
            set vol to sound volume as text
            set sh to shuffle enabled as text
            set rp to song repeat as text
            set {tid, nm, ar, al, pos, du, idx, cnt} to {"", "", "", "", "", "", "", ""}
            try
                set t to current track
                set tid to persistent ID of t
                set nm to name of t
                set ar to artist of t
                set al to album of t
                set du to (duration of t) as text
                set pos to player position as text
                set idx to (index of t) as text
                set cnt to (count of tracks of current playlist) as text
            end try
            return pst & fs & vol & fs & sh & fs & rp & fs & tid & fs & nm & fs & ar & fs & al & fs & pos & fs & du & fs & idx & fs & cnt
        end tell
        """

    /// User playlists (excluding folders and special lists): ids and names as two columns.
    public static let playlists = columnScript(
        fetch: """
            set c1 to persistent ID of every user playlist whose special kind is none
            set c2 to name of every user playlist whose special kind is none
            """,
        columns: ["c1", "c2"]
    )

    public static let playPause = #"tell application "Music" to playpause"#
    public static let nextTrack = #"tell application "Music" to next track"#
    /// Restarts the track, or goes to the previous one near the start (iPod behaviour).
    public static let previousTrack = #"tell application "Music" to back track"#
    public static let shuffleAll = """
        tell application "Music"
            set shuffle enabled to true
            play library playlist 1
        end tell
        """
    /// Raw artwork bytes of the current track.
    public static let artwork = #"tell application "Music" to get raw data of artwork 1 of current track"#

    /// Track ids, titles and artists of a container as three columns.
    public static func tracks(in container: Container) throws -> String {
        let src = try reference(container)
        return columnScript(
            fetch: """
                set src to \(src)
                set c1 to persistent ID of every track of src
                set c2 to name of every track of src
                set c3 to artist of every track of src
                """,
            columns: ["c1", "c2", "c3"]
        )
    }

    /// Plays a track so that playback continues through `container`.
    /// `position` is the track's 1-based place in a playlist; it is ignored for the library.
    public static func play(trackID: String, position: Int, in container: Container) throws -> String {
        try validate(trackID)
        switch container {
        case .library:
            return #"tell application "Music" to play (first track of library playlist 1 whose persistent ID is "\#(trackID)")"#
        case .playlist(let playlistID):
            guard position >= 1 else { throw MusicScriptError.invalidPosition(position) }
            return try playInPlaylist(trackID: trackID, playlistID: playlistID, muteWhileSkipping: position > 1)
        }
    }

    /// Music ignores `play <track>` for Apple Music (streamed) tracks, but `play <playlist>` works.
    /// So start the playlist muted and unshuffled, skip forward to the track while waiting for each
    /// one to load, then restore volume and shuffle. Raises `trackNotStartedError` if it never arrives.
    private static func playInPlaylist(trackID: String, playlistID: String, muteWhileSkipping: Bool) throws -> String {
        let playlist = try reference(.playlist(id: playlistID))
        return """
            tell application "Music"
                set p to \(playlist)
                set savedVolume to sound volume
                set savedShuffle to shuffle enabled
                set reached to false
                try
                    if \(muteWhileSkipping) then set sound volume to 0
                    set shuffle enabled to false
                    play p
                    repeat \(startPolls) times
                        delay 0.25
                        if player state is playing then exit repeat
                    end repeat
                    -- Skip until the track arrives rather than a fixed count:
                    -- Music silently skips tracks it cannot play.
                    repeat (count of tracks of p) times
                        if persistent ID of current track is "\(trackID)" then exit repeat
                        set prevID to persistent ID of current track
                        next track
                        repeat \(startPolls) times
                            delay 0.25
                            try
                                if persistent ID of current track is not prevID and player state is playing then exit repeat
                            end try
                        end repeat
                    end repeat
                    set reached to (persistent ID of current track is "\(trackID)")
                end try
                -- Stop rather than leave some other track playing at full volume.
                if not reached then pause
                set sound volume to savedVolume
                set shuffle enabled to savedShuffle
                if not reached then error "Track did not start" number \(trackNotStartedError)
            end tell
            """
    }

    public static func setVolume(_ volume: Int) -> String {
        let v = min(max(volume, volumeRange.lowerBound), volumeRange.upperBound)
        return #"tell application "Music" to set sound volume to \#(v)"#
    }

    public static func setShuffle(_ on: Bool) -> String {
        #"tell application "Music" to set shuffle enabled to \#(on)"#
    }

    public static func setRepeat(_ mode: RepeatMode) -> String {
        #"tell application "Music" to set song repeat to \#(mode.rawValue)"#
    }

    /// Persistent IDs are hex strings; anything else is rejected to prevent script injection.
    public static func isValidPersistentID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= maxPersistentIDLength && id.allSatisfy(\.isHexDigit)
    }

    private static func validate(_ id: String) throws {
        guard isValidPersistentID(id) else { throw MusicScriptError.invalidPersistentID(id) }
    }

    private static func reference(_ container: Container) throws -> String {
        switch container {
        case .library:
            return "library playlist 1"
        case .playlist(let id):
            try validate(id)
            return #"(first user playlist whose persistent ID is "\#(id)")"#
        }
    }

    /// Runs `fetch` inside a Music tell block, then joins each list variable with ASCII 30
    /// and the columns with ASCII 29.
    private static func columnScript(fetch: String, columns: [String]) -> String {
        let joined = columns.map { "(\($0) as text)" }.joined(separator: " & (character id 29) & ")
        return """
            tell application "Music"
            \(fetch)
            end tell
            set AppleScript's text item delimiters to (character id 30)
            set out to \(joined)
            set AppleScript's text item delimiters to ""
            return out
            """
    }
}
