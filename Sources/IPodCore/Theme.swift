import Foundation

/// An sRGB color with components in 0...1.
public struct RGBColor: Codable, Equatable, Sendable {
    /// Luminance above which a color counts as light (dark text on top).
    private static let lightThreshold = 0.5

    public var red: Double
    public var green: Double
    public var blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    /// Perceived brightness (Rec. 709 weights on sRGB values).
    public var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    public var isLight: Bool { luminance > Self.lightThreshold }

    /// Mixes toward white (positive `amount`) or black (negative), `amount` in -1...1.
    public func adjusted(by amount: Double) -> RGBColor {
        let target = amount > 0 ? 1.0 : 0.0
        let t = min(abs(amount), 1)
        return RGBColor(red + (target - red) * t, green + (target - green) * t, blue + (target - blue) * t)
    }

    private static func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}

/// User-editable look of the widget.
public struct Theme: Codable, Equatable, Sendable {
    public var bodyColor: RGBColor
    public var screenColor: RGBColor

    public init(bodyColor: RGBColor, screenColor: RGBColor) {
        self.bodyColor = bodyColor
        self.screenColor = screenColor
    }

    public static let `default` = Theme(
        bodyColor: ThemePresets.body[0].color,
        screenColor: ThemePresets.screen[0].color
    )

    /// Decodes stored data; missing or unreadable data yields the default theme.
    public static func decode(_ data: Data?) -> Theme {
        guard let data, let theme = try? JSONDecoder().decode(Theme.self, from: data) else { return .default }
        return theme
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

public struct ThemePreset: Sendable {
    public let name: String
    public let color: RGBColor
}

public enum ThemePresets {
    public static let body = [
        ThemePreset(name: "White", color: RGBColor(0.96, 0.96, 0.96)),
        ThemePreset(name: "Black", color: RGBColor(0.13, 0.13, 0.14)),
        ThemePreset(name: "Silver", color: RGBColor(0.78, 0.79, 0.81)),
        ThemePreset(name: "Space Gray", color: RGBColor(0.33, 0.34, 0.37)),
        ThemePreset(name: "Pink", color: RGBColor(0.96, 0.67, 0.78)),
        ThemePreset(name: "Blue", color: RGBColor(0.45, 0.66, 0.90)),
        ThemePreset(name: "Green", color: RGBColor(0.60, 0.82, 0.45)),
        ThemePreset(name: "Red", color: RGBColor(0.78, 0.12, 0.16)),
    ]

    public static let screen = [
        ThemePreset(name: "Classic Blue", color: RGBColor(0.74, 0.82, 0.92)),
        ThemePreset(name: "Mono Gray", color: RGBColor(0.78, 0.80, 0.76)),
        ThemePreset(name: "Backlit Green", color: RGBColor(0.62, 0.80, 0.42)),
        ThemePreset(name: "Amber", color: RGBColor(0.95, 0.68, 0.25)),
        ThemePreset(name: "White", color: RGBColor(0.97, 0.97, 0.97)),
    ]
}

/// Every color the widget draws, derived from the two base colors of a theme.
public struct ThemeColors: Equatable, Sendable {
    public let bodyTop, bodyBottom, bodyEdge: RGBColor
    public let wheelFace, wheelEdge, wheelLabel, centerFace: RGBColor
    public let lcdTop, lcdBottom, lcdText: RGBColor
    public let highlightTop, highlightBottom, highlightText: RGBColor

    private static let wheelWhite = RGBColor(0.95, 0.95, 0.95)
    private static let darkText = RGBColor(0.06, 0.10, 0.20)
    private static let lightText = RGBColor(0.93, 0.95, 1.00)
    private static let navyTop = RGBColor(0.20, 0.27, 0.55)
    private static let navyBottom = RGBColor(0.11, 0.16, 0.38)

    public init(theme: Theme) {
        let body = theme.bodyColor
        bodyTop = body.adjusted(by: 0.06)
        bodyBottom = body.adjusted(by: -0.08)
        bodyEdge = body.adjusted(by: -0.2)
        // The wheel stays white on every body color; only the center button follows the body.
        wheelFace = Self.wheelWhite
        wheelEdge = Self.wheelWhite.adjusted(by: -0.15)
        wheelLabel = Self.wheelWhite.adjusted(by: -0.3)
        centerFace = body

        let screen = theme.screenColor
        lcdTop = screen.adjusted(by: 0.3)
        lcdBottom = screen.adjusted(by: -0.08)
        if screen.isLight {
            lcdText = Self.darkText
            highlightTop = Self.navyTop
            highlightBottom = Self.navyBottom
            highlightText = Self.lightText
        } else {
            lcdText = Self.lightText
            highlightTop = Self.lightText
            highlightBottom = Self.lightText.adjusted(by: -0.15)
            highlightText = screen.adjusted(by: -0.3)
        }
    }
}
