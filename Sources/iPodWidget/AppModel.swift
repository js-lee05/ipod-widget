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

    private let music = MusicController()
    private var pollTask: Task<Void, Never>?
    private var artworkTrackID: String?
    private var scrollAccumulator: CGFloat = 0

    init() {
        navigator = MenuNavigator(
            root: MenuPage(kind: .root, title: "iPod", items: Self.rootItems(hasTrack: false)),
            visibleRows: Layout.visibleRows
        )
    }

    var screenTitle: String { showingNowPlaying ? "Now Playing" : navigator.current.title }

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
        guard music.isRunning else {
            nowPlaying = nil
            artwork = nil
            artworkTrackID = nil
            notice = "Music not running"
            syncMenus()
            return
        }
        do {
            let status = try MusicParser.nowPlaying(try await music.text(MusicScripts.status))
            nowPlaying = status
            notice = nil
            if status.trackID != artworkTrackID {
                artworkTrackID = status.trackID
                artwork = await loadArtwork(hasTrack: status.trackID != nil)
            }
        } catch {
            report(error)
        }
        syncMenus()
    }

    private func loadArtwork(hasTrack: Bool) async -> NSImage? {
        guard hasTrack else { return nil }
        do {
            return NSImage(data: try await music.data(MusicScripts.artwork))
        } catch MusicError.script {
            return nil  // track has no artwork
        } catch {
            report(error)
            return nil
        }
    }

    private func syncMenus() {
        navigator.updateItems(of: .root, to: Self.rootItems(hasTrack: nowPlaying?.trackID != nil))
        navigator.updateItems(of: .settings, to: Self.settingsItems(nowPlaying))
    }

    // MARK: Wheel input

    func rotate(_ steps: Int) {
        if showingNowPlaying {
            guard var status = nowPlaying else { return }
            status.volume = min(max(status.volume + steps * Input.volumeStep, 0), 100)
            nowPlaying = status
            volumeVisibleUntil = Date().addingTimeInterval(Timing.volumeOverlay)
            command(MusicScripts.setVolume(status.volume))
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
        case .previous: command(MusicScripts.previousTrack)
        case .next: command(MusicScripts.nextTrack)
        case .playPause: command(MusicScripts.playPause)
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
                try await self.tracks(in: .playlist(id: playlist.id))
                    .map { MenuItem($0.title, action: .playTrack(id: $0.id, container: .playlist(id: playlist.id))) }
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
                    .map { MenuItem($0.title, action: .playTrack(id: $0.id, container: .library)) }
            }
        case .songs:
            await pushLoaded(kind: .songs, title: "Songs") {
                try await self.sortedLibrarySongs()
                    .map { MenuItem($0.title, action: .playTrack(id: $0.id, container: .library)) }
            }
        case .playTrack(let id, let container):
            do {
                try await music.perform(try MusicScripts.play(trackID: id, in: container))
                showNowPlaying()
            } catch {
                report(error)
            }
        case .shuffleSongs:
            command(MusicScripts.shuffleAll)
            showNowPlaying()
        case .toggleShuffle:
            command(MusicScripts.setShuffle(!(nowPlaying?.shuffle ?? false)))
        case .cycleRepeat:
            command(MusicScripts.setRepeat((nowPlaying?.repeatMode ?? .off).next))
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

    /// Sends a fire-and-forget command, then refreshes the status.
    private func command(_ source: String) {
        Task {
            do {
                try await music.perform(source)
            } catch {
                report(error)
            }
            await refresh()
        }
    }

    private func report(_ error: Error) {
        switch error {
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

    private static func rootItems(hasTrack: Bool) -> [MenuItem] {
        var items = [
            MenuItem("Music", chevron: true, action: .music),
            MenuItem("Settings", chevron: true, action: .settings),
            MenuItem("Shuffle Songs", action: .shuffleSongs),
            MenuItem("Backlight", action: .toggleBacklight),
        ]
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
