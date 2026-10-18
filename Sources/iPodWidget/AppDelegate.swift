import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let themeStore = ThemeStore()
    private let mover = WindowMover()
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var scrollMonitor: Any?
    private var customizeWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = makePanel()
        self.panel = panel
        mover.window = panel
        installStatusItem()
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            self.model.scroll(deltaY: event.scrollingDeltaY, precise: event.hasPreciseScrollingDeltas)
            return nil
        }
        model.start()
        log.info("iPod widget started")
    }

    /// Borderless panel just above the desktop icons and below all normal windows, on every Space.
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Layout.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // the view draws its own drop shadow
        panel.contentView = NSHostingView(rootView: IPodView(model: model, themeStore: themeStore, mover: mover))

        let restored = panel.setFrameUsingName(Defaults.windowAutosaveName)
        panel.setFrameAutosaveName(Defaults.windowAutosaveName)
        // A saved position can end up off-screen after a display change.
        if !restored || !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
            panel.center()
        }
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        return panel
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "ipod", accessibilityDescription: "iPod Widget")
        let menu = NSMenu()
        let customize = NSMenuItem(title: "Customize…", action: #selector(showCustomize), keyEquivalent: ",")
        customize.target = self
        menu.addItem(customize)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit iPod Widget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    /// Opens the single Customize window, bringing it forward if it already exists.
    @objc private func showCustomize() {
        let window = customizeWindow ?? makeCustomizeWindow()
        customizeWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeCustomizeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: CustomizeView(store: themeStore)))
        window.title = "Customize iPod"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
