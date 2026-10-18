import Foundation
import os

enum Layout {
    static let deviceSize = CGSize(width: 260, height: 430)
    /// Transparent margin around the device so its drop shadow is not clipped.
    static let shadowMargin: CGFloat = 18
    static var windowSize: CGSize {
        CGSize(width: deviceSize.width + shadowMargin * 2, height: deviceSize.height + shadowMargin * 2)
    }
    static let bodyCornerRadius: CGFloat = 18
    static let bodyPadding: CGFloat = 16
    static let titleBarHeight: CGFloat = 22
    static let rowHeight: CGFloat = 24
    static let visibleRows = 6
    static var screenHeight: CGFloat { titleBarHeight + rowHeight * CGFloat(visibleRows) }
    static let bezelWidth: CGFloat = 7
    static let screenToWheelSpacing: CGFloat = 30
    static let wheelDiameter: CGFloat = 158
    static let centerButtonDiameter: CGFloat = 60
    static let artworkSize: CGFloat = 54
}

enum Timing {
    static let pollInterval: Duration = .seconds(1)
    static let volumeOverlay: TimeInterval = 2
}

enum Input {
    /// Degrees of wheel rotation per menu step.
    static let wheelStepDegrees = 18.0
    /// Total rotation/translation below which a wheel gesture counts as a click.
    static let tapMaxDegrees = 6.0
    static let tapMaxTranslation: CGFloat = 6
    /// Scroll delta per step for trackpads (precise) and mice (line-based).
    static let preciseScrollStep: CGFloat = 14
    static let lineScrollStep: CGFloat = 1
    static let volumeStep = 2
}

enum Defaults {
    static let windowAutosaveName = "iPodWidgetWindow"
}

let log = Logger(subsystem: "local.ipodwidget", category: "app")
