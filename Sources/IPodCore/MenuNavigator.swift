import Foundation

/// What selecting a menu item does.
public enum MenuAction: Equatable, Sendable {
    case none
    case music, playlists, artists, songs, settings
    case playlist(Playlist)
    case artist(String)
    /// `position` is the 1-based place of the track in `container`.
    case playTrack(id: String, position: Int, container: Container)
    case shuffleSongs, toggleShuffle, cycleRepeat, toggleBacklight, nowPlaying
}

public struct MenuItem: Equatable, Sendable {
    public let title: String
    public let showsChevron: Bool
    public let action: MenuAction

    public init(_ title: String, chevron: Bool = false, action: MenuAction) {
        self.title = title
        self.showsChevron = chevron
        self.action = action
    }
}

/// One screen of the iPod menu, with its own selection and scroll offset.
public struct MenuPage: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case root, music, playlists, playlist, artists, artist, songs, settings, message
    }

    public let kind: Kind
    public let title: String
    public internal(set) var items: [MenuItem]
    public internal(set) var selection = 0
    /// Index of the first visible row.
    public internal(set) var top = 0

    public init(kind: Kind, title: String, items: [MenuItem]) {
        self.kind = kind
        self.title = title
        self.items = items
    }
}

/// Stack-based menu navigation driven by the click wheel.
public struct MenuNavigator: Equatable, Sendable {
    public let visibleRows: Int
    public private(set) var stack: [MenuPage]

    public init(root: MenuPage, visibleRows: Int) {
        precondition(visibleRows > 0, "visibleRows must be positive")
        self.visibleRows = visibleRows
        self.stack = [root]
    }

    public var current: MenuPage { stack[stack.count - 1] }

    public var selectedItem: MenuItem? {
        current.items.indices.contains(current.selection) ? current.items[current.selection] : nil
    }

    /// Moves the selection by `steps` (positive = down), clamped, scrolling to keep it visible.
    public mutating func move(by steps: Int) {
        var page = current
        guard !page.items.isEmpty else { return }
        page.selection = min(max(page.selection + steps, 0), page.items.count - 1)
        clampTop(&page)
        stack[stack.count - 1] = page
    }

    public mutating func push(_ page: MenuPage) {
        stack.append(page)
    }

    /// Returns to the previous page. Returns `false` at the root.
    @discardableResult
    public mutating func pop() -> Bool {
        guard stack.count > 1 else { return false }
        stack.removeLast()
        return true
    }

    /// Replaces the items of every page of `kind` in the stack, keeping selection in range.
    public mutating func updateItems(of kind: MenuPage.Kind, to items: [MenuItem]) {
        for i in stack.indices where stack[i].kind == kind {
            stack[i].items = items
            stack[i].selection = min(stack[i].selection, max(items.count - 1, 0))
            clampTop(&stack[i])
        }
    }

    private func clampTop(_ page: inout MenuPage) {
        if page.selection < page.top {
            page.top = page.selection
        } else if page.selection >= page.top + visibleRows {
            page.top = page.selection - visibleRows + 1
        }
        page.top = min(page.top, max(page.items.count - visibleRows, 0))
    }
}
