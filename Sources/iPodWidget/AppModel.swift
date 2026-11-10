import AppKit
import IPodCore

enum WheelButton {
    case menu, previous, next, playPause
}

/// Holds the iPod UI state and translates wheel input into menu moves and Music commands.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var navigator: MenuNavigator
    @Published private(set) var nowPlaying: NowPlaying?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var showingNowPlaying = false
    @Published private(set) var backlightOn = true
    @Published private(set) var notice: String?
    @Published private(set) var volumeVisibleUntil = Date.distantPast
    @Published private(set) var source: MusicSource

    private let music = MusicController()
    private let youTube = YouTubeMusicClient()
    private let defaults: UserDefaults
    private var pollTask: Task<Void, Never>?
    private var artworkTrackID: String?
    private var scrollAccumulator: CGFloat = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let source = defaults.string(forKey: Defaults.musicSourceKey).flatMap(MusicSource.init) ?? .appleMusic
        self.source = source
        navigator = Self.rootNavigator(source: source)
    }

    var screenTitle: String { showingNowPlaying ? "Now Playing" : navigator.current.title }

    private var player: PlayerBackend {
        switch source {
        case .appleMusic: return music
        case .youtubeMusic: return youTube
        }
    }

    /// Switches the controlled app, returning to the root menu.
    func setSource(_ newSource: MusicSource) {
        guard newSource != source else { return }
        source = newSource
        defaults.set(newSource.rawValue, forKey: Defaults.musicSourceKey)
        navigator = Self.rootNavigator(source: newSource)
        showingNowPlaying = false
        nowPlaying = nil
        artwork = nil
        artworkTrackID = nil
        notice = nil
        if newSource == .youtubeMusic {
            Task { await youTube.allowAccessRequest() }
        }
        Task { await refresh() }
    }

    private static func rootNavigator(source: MusicSource) -> MenuNavigator {
        MenuNavigator(
            root: MenuPage(kind: .root, title: "iPod", items: rootItems(hasTrack: false, source: source)),
            visibleRows: Layout.visibleRows
        )
    }

    // MARK: Polling

    func start() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Timing.pollInterval)
            }
        }
    }

    func refresh() async {
        let polled = source
        let player = player
        do {
            let status = try await player.status()
            guard source == polled else { return }  // source switched while waiting
            nowPlaying = status
            notice = nil
            if status.trackID != artworkTrackID {
                artworkTrackID = status.trackID
                let image = await loadArtwork(from: player, hasTrack: status.trackID != nil)
                guard source == polled else { return }
                artwork = image
            }
        } catch MusicError.notRunning {
            guard source == polled else { return }
            nowPlaying = nil
            artwork = nil
            artworkTrackID = nil
            notice = "\(source.displayName) not running"
        } catch {
            guard source == polled else { return }
            report(error)
        }
        syncMenus()
    }

    private func loadArtwork(from player: PlayerBackend, hasTrack: Bool) async -> NSImage? {
        guard hasTrack else { return nil }
        do {
            return try await player.artwork()
        } catch let error as URLError {
            log.warning("Artwork download failed: \(error.code.rawValue)")
            return nil
        } catch {
            report(error)
            return nil
        }
    }

    private func syncMenus() {
        navigator.updateItems(of: .root, to: Self.rootItems(hasTrack: nowPlaying?.trackID != nil, source: source))
        navigator.updateItems(of: .settings, to: Self.settingsItems(nowPlaying))
    }

    // MARK: Wheel input

    func rotate(_ steps: Int) {
        if showingNowPlaying {
            guard var status = nowPlaying else { return }
            status.volume = min(max(status.volume + steps * Input.volumeStep, 0), 100)
            nowPlaying = status
            volumeVisibleUntil = Date().addingTimeInterval(Timing.volumeOverlay)
            command { try await $0.setVolume(status.volume) }
        } else {
            navigator.move(by: steps)
        }
    }

    func scroll(deltaY: CGFloat, precise: Bool) {
        scrollAccumulator += deltaY
        let step = precise ? Input.preciseScrollStep : Input.lineScrollStep
        let steps = Int(scrollAccumulator / step)
        guard steps != 0 else { return }
        scrollAccumulator -= CGFloat(steps) * step
        rotate(steps)
    }

    func press(_ button: WheelButton) {
        switch button {
        case .menu:
            if showingNowPlaying { showingNowPlaying = false } else { navigator.pop() }
        case .previous: command { try await $0.previousTrack() }
        case .next: command { try await $0.nextTrack() }
        case .playPause: command { try await $0.playPause() }
        }
    }

    func select() {
        guard !showingNowPlaying, let item = navigator.selectedItem else { return }
        Task { await perform(item.action) }
    }

    // MARK: Actions

    private func perform(_ action: MenuAction) async {
        switch action {
        case .none:
            break
        case .music where source == .youtubeMusic, .queue:
            await pushLoaded(kind: .queue, title: "Queue") {
                try await self.youTube.queue().enumerated().map { offset, item in
                    MenuItem(item.title, action: .playQueueItem(index: offset))
                }
            }
        case .playQueueItem(let index):
            do {
                try await youTube.playQueueItem(at: index)
                showNowPlaying()
            } catch {
                report(error)
            }
        case .music:
            navigator.push(MenuPage(kind: .music, title: "Music", items: [
                MenuItem("Playlists", chevron: true, action: .playlists),
                MenuItem("Artists", chevron: true, action: .artists),
                MenuItem("Songs", chevron: true, action: .songs),
            ]))
        case .settings:
            navigator.push(MenuPage(kind: .settings, title: "Settings", items: Self.settingsItems(nowPlaying)))
        case .playlists:
            await pushLoaded(kind: .playlists, title: "Playlists") {
                try MusicParser.playlists(try await self.music.text(MusicScripts.playlists))
                    .map { MenuItem($0.name, chevron: true, action: .playlist($0)) }
            }
        case .playlist(let playlist):
            await pushLoaded(kind: .playlist, title: playlist.name) {
                try await self.tracks(in: .playlist(id: playlist.id)).enumerated().map { offset, track in
                    MenuItem(track.title, action: .playTrack(id: track.id, position: offset + 1, container: .playlist(id: playlist.id)))
                }
            }
        case .artists:
            await pushLoaded(kind: .artists, title: "Artists") {
                Set(try await self.tracks(in: .library).map(\.artist).filter { !$0.isEmpty })
                    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                    .map { MenuItem($0, chevron: true, action: .artist($0)) }
            }
        case .artist(let name):
            await pushLoaded(kind: .artist, title: name) {
                try await self.sortedLibrarySongs().filter { $0.artist == name }
                    .map { MenuItem($0.title, action: .playTrack(id: $0.id, position: 1, container: .library)) }
            }
        case .songs:
            await pushLoaded(kind: .songs, title: "Songs") {
                try await self.sortedLibrarySongs()
                    .map { MenuItem($0.title, action: .playTrack(id: $0.id, position: 1, container: .library)) }
            }
        case .playTrack(let id, let position, let container):
            do {
                try await music.perform(try MusicScripts.play(trackID: id, position: position, in: container))
                showNowPlaying()
            } catch {
                report(error)
            }
        case .shuffleSongs:
            command { [music] _ in try await music.perform(MusicScripts.shuffleAll) }
            showNowPlaying()
        case .toggleShuffle:
            let current = nowPlaying?.shuffle ?? false
            command { try await $0.toggleShuffle(from: current) }
        case .cycleRepeat:
            let current = nowPlaying?.repeatMode ?? .off
            command { try await $0.setRepeat(current.next, from: current) }
        case .toggleBacklight:
            backlightOn.toggle()
        case .nowPlaying:
            showNowPlaying()
        }
    }

    private func showNowPlaying() {
        showingNowPlaying = true
        Task { await refresh() }
    }

    private func tracks(in container: Container) async throws -> [Track] {
        try MusicParser.tracks(try await music.text(try MusicScripts.tracks(in: container)))
    }

    private func sortedLibrarySongs() async throws -> [Track] {
        try await tracks(in: .library).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Pushes a page built by `load`; on failure pushes a page showing the error instead.
    private func pushLoaded(kind: MenuPage.Kind, title: String, load: () async throws -> [MenuItem]) async {
        do {
            navigator.push(MenuPage(kind: kind, title: title, items: try await load()))
        } catch {
            report(error)
            navigator.push(MenuPage(kind: .message, title: title, items: [MenuItem(notice ?? "Error", action: .none)]))
        }
    }

    /// Sends a fire-and-forget command to the current player, then refreshes the status.
    private func command(_ action: @escaping (PlayerBackend) async throws -> Void) {
        let player = player
        Task {
            do {
                try await action(player)
            } catch {
                report(error)
            }
            await refresh()
        }
    }

    private func report(_ error: Error) {
        switch error {
        case MusicError.notRunning:
            notice = "\(source.displayName) not running"
        case MusicError.accessDenied:
            notice = "Allow iPod Widget in YouTube Music"
            log.warning("YouTube Music denied API access")
        case MusicError.http(let status):
            notice = "YouTube Music error \(status)"
            log.error("YouTube Music API returned HTTP \(status)")
        case let error as URLError:
            notice = "YouTube Music unreachable"
            log.error("YouTube Music request failed: \(error.code.rawValue)")
        case MusicError.permissionDenied:
            notice = "Allow Music in Settings > Privacy > Automation"
            log.warning("Automation permission for Music denied")
        case MusicError.script(let code, let message):
            notice = "Music error \(code)"
            log.error("AppleScript error \(code): \(message, privacy: .public)")
        default:
            notice = "Unexpected response"
            log.error("Unexpected error: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Menus

    private static func rootItems(hasTrack: Bool, source: MusicSource) -> [MenuItem] {
        var items = [
            MenuItem("Music", chevron: true, action: .music),
            MenuItem("Settings", chevron: true, action: .settings),
        ]
        // Shuffling the whole library needs library access, which only Music.app offers.
        if source == .appleMusic { items.append(MenuItem("Shuffle Songs", action: .shuffleSongs)) }
        items.append(MenuItem("Backlight", action: .toggleBacklight))
        if hasTrack { items.append(MenuItem("Now Playing", chevron: true, action: .nowPlaying)) }
        return items
    }

    private static func settingsItems(_ status: NowPlaying?) -> [MenuItem] {
        [
            MenuItem("Shuffle: \(status?.shuffle == true ? "On" : "Off")", action: .toggleShuffle),
            MenuItem("Repeat: \((status?.repeatMode ?? .off).rawValue.capitalized)", action: .cycleRepeat),
        ]
    }
}
