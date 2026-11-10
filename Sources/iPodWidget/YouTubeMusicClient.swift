import AppKit
import IPodCore
import Security

/// Talks to the API Server plugin of the YouTube Music desktop app (th-ch/youtube-music).
///
/// The first request asks the app for an access token, which shows an allow/deny dialog there.
/// The token is kept in the Keychain so the dialog appears only once.
actor YouTubeMusicClient: PlayerBackend {
    private let session: URLSession
    private var token: String?
    private var authTask: Task<String, Error>?
    /// Set when the user clicked Deny, so polling does not reopen the dialog every second.
    private var accessDenied = false
    private var artworkURL: URL?

    init(session: URLSession = .shared) {
        self.session = session
        token = TokenKeychain.read()
    }

    /// Lets the next request show the approval dialog again after a Deny.
    func allowAccessRequest() {
        accessDenied = false
    }

    // MARK: PlayerBackend

    func status() async throws -> NowPlaying {
        async let song = get("song")
        async let volume = get("volume")
        async let shuffle = get("shuffle")
        async let repeatMode = get("repeat-mode")
        let status = try YouTubeMusicParser.status(
            song: try await song, volume: try await volume ?? Data(),
            shuffle: try await shuffle ?? Data(), repeatMode: try await repeatMode ?? Data()
        )
        artworkURL = status.artworkURL
        return status.nowPlaying
    }

    func artwork() async throws -> NSImage? {
        guard let artworkURL else { return nil }
        let (data, _) = try await session.data(from: artworkURL)
        return NSImage(data: data)
    }

    func playPause() async throws { try await post("toggle-play") }
    func nextTrack() async throws { try await post("next") }
    func previousTrack() async throws { try await post("previous") }
    func setVolume(_ volume: Int) async throws { try await post("volume", body: ["volume": volume]) }
    /// `/shuffle` presses the shuffle button, which flips the state.
    func toggleShuffle(from current: Bool) async throws { try await post("shuffle") }
    func setRepeat(_ mode: RepeatMode, from current: RepeatMode) async throws {
        let presses = YouTubeMusicParser.repeatPresses(from: current, to: mode)
        guard presses > 0 else { return }
        try await post("switch-repeat", body: ["iteration": presses])
    }

    // MARK: Queue

    func queue() async throws -> [QueueItem] {
        guard let data = try await get("queue") else { return [] }
        return try YouTubeMusicParser.queue(data)
    }

    /// Jumps to the 0-based `index` of the queue.
    func playQueueItem(at index: Int) async throws {
        try await send("PATCH", "queue", body: ["index": index])
    }

    // MARK: HTTP

    private func get(_ path: String) async throws -> Data? {
        try await send("GET", path, body: nil)
    }

    private func post(_ path: String, body: [String: Int]? = nil) async throws {
        try await send("POST", path, body: body)
    }

    /// Sends an authorized API request. Returns `nil` for 204 No Content.
    @discardableResult
    private func send(_ method: String, _ path: String, body: [String: Int]?) async throws -> Data? {
        var request = URLRequest(url: YouTubeMusicAPI.baseURL.appending(path: "api/v1/\(path)"),
                                 timeoutInterval: YouTubeMusicAPI.requestTimeout)
        request.httpMethod = method
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, status) = try await load(request)
        switch status {
        case 200: return data
        case 204: return nil
        case 401:
            // Token no longer valid (e.g. the app's client list was reset): request a new one next time.
            token = nil
            TokenKeychain.delete()
            throw MusicError.http(status: status)
        default:
            throw MusicError.http(status: status)
        }
    }

    private func accessToken() async throws -> String {
        if let token { return token }
        if accessDenied { throw MusicError.accessDenied }
        // Polling calls this every second; share one request so only one dialog opens.
        let task = authTask ?? Task { try await requestToken() }
        authTask = task
        defer { authTask = nil }
        do {
            let newToken = try await task.value
            token = newToken
            TokenKeychain.save(newToken)
            return newToken
        } catch MusicError.accessDenied {
            accessDenied = true
            throw MusicError.accessDenied
        }
    }

    private struct AuthResponse: Decodable { let accessToken: String }

    private func requestToken() async throws -> String {
        var request = URLRequest(url: YouTubeMusicAPI.baseURL.appending(path: "auth/\(YouTubeMusicAPI.clientID)"),
                                 timeoutInterval: YouTubeMusicAPI.authTimeout)
        request.httpMethod = "POST"
        let (data, status) = try await load(request)
        switch status {
        case 200: return try JSONDecoder().decode(AuthResponse.self, from: data).accessToken
        case 403: throw MusicError.accessDenied
        default: throw MusicError.http(status: status)
        }
    }

    /// Maps "nothing listening on the port" to `notRunning`.
    private func load(_ request: URLRequest) async throws -> (Data, Int) {
        do {
            let (data, response) = try await session.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch let error as URLError where [.cannotConnectToHost, .networkConnectionLost, .timedOut].contains(error.code) {
            throw MusicError.notRunning
        }
    }
}

/// Stores the YouTube Music access token as a generic password in the login Keychain.
private enum TokenKeychain {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: YouTubeMusicAPI.keychainService,
            kSecAttrAccount as String: YouTubeMusicAPI.clientID,
        ]
    }

    static func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound { log.error("Keychain read failed: \(status)") }
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func save(_ token: String) {
        delete()
        var q = query
        q[kSecValueData as String] = Data(token.utf8)
        let status = SecItemAdd(q as CFDictionary, nil)
        if status != errSecSuccess { log.error("Keychain save failed: \(status)") }
    }

    static func delete() {
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound { log.error("Keychain delete failed: \(status)") }
    }
}
