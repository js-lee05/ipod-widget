import AppKit
import IPodCore
import SwiftUI

/// Persists the user's theme in UserDefaults and publishes changes to the widget.
@MainActor
final class ThemeStore: ObservableObject {
    private static let defaultsKey = "theme"
    private let defaults: UserDefaults

    @Published var theme: Theme {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = Theme.decode(defaults.data(forKey: Self.defaultsKey))
    }

    func reset() {
        theme = .default
    }

    private func save() {
        do {
            defaults.set(try theme.encoded(), forKey: Self.defaultsKey)
        } catch let error as EncodingError {
            log.error("Failed to save theme: \(String(describing: error), privacy: .public)")
        } catch {
            log.error("Unexpected error saving theme: \(String(describing: error), privacy: .public)")
        }
    }
}

/// Colors and font the views draw with, derived from a theme.
struct Style {
    let colors: ThemeColors

    init(theme: Theme) {
        colors = ThemeColors(theme: theme)
    }

    /// Screen font: the system font at a fixed size.
    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

private struct StyleKey: EnvironmentKey {
    static let defaultValue = Style(theme: .default)
}

extension EnvironmentValues {
    var style: Style {
        get { self[StyleKey.self] }
        set { self[StyleKey.self] = newValue }
    }
}

extension Color {
    init(_ rgb: IPodCore.RGBColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

extension IPodCore.RGBColor {
    /// Converts any color (P3, grayscale, ...) to sRGB; `nil` for colors without RGB equivalent (patterns).
    init?(_ color: Color) {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
    }
}
