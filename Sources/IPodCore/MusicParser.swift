import Foundation

/// Errors raised when AppleScript output does not have the expected shape.
public enum MusicParseError: Error, Equatable {
    case fieldCount(expected: Int, actual: Int)
    case columnMismatch
}

/// Parses the delimited text returned by `MusicScripts`.
public enum MusicParser {
    /// Field separator (ASCII 31, unit separator).
    public static let fieldSeparator: Character = "\u{1F}"
    /// Record separator (ASCII 30).
    public static let recordSeparator: Character = "\u{1E}"
    /// Column separator (ASCII 29, group separator).
    public static let columnSeparator: Character = "\u{1D}"

    private static let statusFieldCount = 12

    /// Parses the output of `MusicScripts.status`.
    public static func nowPlaying(_ text: String) throws -> NowPlaying {
        let f = text.split(separator: fieldSeparator, omittingEmptySubsequences: false).map(String.init)
        guard f.count == statusFieldCount else {
            throw MusicParseError.fieldCount(expected: statusFieldCount, actual: f.count)
        }
        let trackID = f[4].isEmpty ? nil : f[4]
        return NowPlaying(
            state: PlayerState(rawValue: f[0]) ?? .playing,  // fast forwarding / rewinding
            volume: Int(f[1]) ?? 0,
            shuffle: f[2] == "true",
            repeatMode: RepeatMode(rawValue: f[3]) ?? .off,
            trackID: trackID,
            title: f[5],
            artist: f[6],
            album: f[7],
            position: number(f[8]),
            duration: number(f[9]),
            index: Int(f[10]),
            count: Int(f[11])
        )
    }

    /// Parses the output of `MusicScripts.tracks(in:)`.
    public static func tracks(_ text: String) throws -> [Track] {
        try columns(text, count: 3).map { Track(id: $0[0], title: $0[1], artist: $0[2]) }
    }

    /// Parses the output of `MusicScripts.playlists`.
    public static func playlists(_ text: String) throws -> [Playlist] {
        try columns(text, count: 2).map { Playlist(id: $0[0], name: $0[1]) }
    }

    /// Splits column-major output into rows of `count` fields.
    private static func columns(_ text: String, count: Int) throws -> [[String]] {
        let cols = text.split(separator: columnSeparator, omittingEmptySubsequences: false)
        guard cols.count == count else { throw MusicParseError.fieldCount(expected: count, actual: cols.count) }
        // The first column holds ids, which are never empty, so an empty first column is an empty list.
        guard !cols[0].isEmpty else {
            guard cols.allSatisfy(\.isEmpty) else { throw MusicParseError.columnMismatch }
            return []
        }
        let values = cols.map { $0.split(separator: recordSeparator, omittingEmptySubsequences: false).map(String.init) }
        let rows = values[0].count
        guard values.allSatisfy({ $0.count == rows }) else {
            throw MusicParseError.columnMismatch
        }
        return (0..<rows).map { i in values.map { $0[i] } }
    }

    /// AppleScript may format reals with a locale decimal comma.
    private static func number(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}
