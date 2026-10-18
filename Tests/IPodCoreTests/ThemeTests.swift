import Foundation
import Testing
@testable import IPodCore

@Test func themeRoundTrips() throws {
    let theme = Theme(bodyColor: RGBColor(0.1, 0.2, 0.3), screenColor: RGBColor(0.9, 0.8, 0.7))
    #expect(Theme.decode(try theme.encoded()) == theme)
}

@Test func unreadableThemeFallsBackToDefault() {
    #expect(Theme.decode(nil) == .default)
    #expect(Theme.decode(Data("not json".utf8)) == .default)
    #expect(Theme.decode(Data(#"{"bodyColor":{"red":1}}"#.utf8)) == .default)
}

@Test func colorComponentsAreClamped() {
    #expect(RGBColor(1.5, -0.2, 0.5) == RGBColor(1, 0, 0.5))
}

@Test func textContrastsWithScreen() {
    let light = ThemeColors(theme: Theme(bodyColor: RGBColor(1, 1, 1), screenColor: RGBColor(0.97, 0.97, 0.97)))
    let dark = ThemeColors(theme: Theme(bodyColor: RGBColor(0, 0, 0), screenColor: RGBColor(0.1, 0.1, 0.2)))
    #expect(!light.lcdText.isLight)
    #expect(light.highlightText.isLight)
    #expect(dark.lcdText.isLight)
    #expect(!dark.highlightText.isLight)
}

@Test func wheelStaysWhiteWhileCenterFollowsBody() {
    let black = RGBColor(0.1, 0.1, 0.1)
    let red = ThemeColors(theme: Theme(bodyColor: RGBColor(0.8, 0.1, 0.1), screenColor: RGBColor(0.7, 0.8, 0.9)))
    let dark = ThemeColors(theme: Theme(bodyColor: black, screenColor: RGBColor(0.7, 0.8, 0.9)))
    #expect(red.wheelFace == dark.wheelFace)
    #expect(dark.wheelFace.isLight)
    #expect(dark.centerFace == black)
}
