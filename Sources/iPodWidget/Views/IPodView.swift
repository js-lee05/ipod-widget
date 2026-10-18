import IPodCore
import SwiftUI

/// Moves the borderless window while the iPod body is dragged.
@MainActor
final class WindowMover {
    weak var window: NSWindow?
    private var startOrigin: NSPoint?
    private var startMouse: NSPoint?

    func drag() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        if startOrigin == nil {
            startOrigin = window.frame.origin
            startMouse = mouse
        }
        guard let startOrigin, let startMouse else { return }
        window.setFrameOrigin(NSPoint(x: startOrigin.x + mouse.x - startMouse.x, y: startOrigin.y + mouse.y - startMouse.y))
    }

    func end() {
        startOrigin = nil
        startMouse = nil
    }
}

struct IPodView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var themeStore: ThemeStore
    let mover: WindowMover

    var body: some View {
        let style = Style(theme: themeStore.theme)
        let shape = RoundedRectangle(cornerRadius: Layout.bodyCornerRadius, style: .continuous)
        let frame = RoundedRectangle(cornerRadius: 4, style: .continuous)
        VStack(spacing: Layout.screenToWheelSpacing) {
            // Screen under the plastic face: thin gray frame set into a shallow recess.
            ScreenView(model: model)
                .frame(height: Layout.screenHeight)
                .padding(Layout.screenFrameWidth)
                .background(frame.fill(Palette.screenFrame))
                .padding(1)
                .background(frame.fill(Self.recessLip))
                .padding(.horizontal, Layout.screenSideInset)
            ClickWheelView(
                onRotate: model.rotate,
                onButton: model.press,
                onCenter: model.select
            )
            .frame(width: Layout.wheelDiameter, height: Layout.wheelDiameter)
            Spacer(minLength: 0)
        }
        .padding(.top, Layout.screenTopInset)
        .frame(width: Layout.deviceSize.width, height: Layout.deviceSize.height)
        .background(PillowBody(colors: style.colors, shape: shape))
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { _ in mover.drag() }
                .onEnded { _ in mover.end() }
        )
        .padding(Layout.shadowMargin)
        .environment(\.style, style)
    }

    /// Edge of a recess: shaded where the face drops in at the top, lit at the bottom.
    private static let recessLip = LinearGradient(
        colors: [.black.opacity(0.25), .white.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Glossy plastic body whose edges roll away from the flat face, lit from the top-left.
private struct PillowBody: View {
    let colors: ThemeColors
    let shape: RoundedRectangle

    var body: some View {
        let rim = Layout.bodyRimWidth
        ZStack {
            // Outer edge: bright where it faces the light, falling into shadow at the bottom-right.
            shape.fill(LinearGradient(
                colors: [Color(colors.bodyTop.adjusted(by: -0.08)), Color(colors.bodyBottom.adjusted(by: -0.38))],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            // Highlight band where the edge starts to curve.
            shape.inset(by: rim * 0.3)
                .fill(Color(colors.bodyTop.adjusted(by: 0.3)))
                .blur(radius: rim * 0.25)
            // Flat face, blended into the rim.
            shape.inset(by: rim)
                .fill(LinearGradient(colors: [Color(colors.bodyTop), Color(colors.bodyBottom)], startPoint: .top, endPoint: .bottom))
                .blur(radius: rim * 0.3)
        }
        .clipShape(shape)
        .overlay(shape.fill(Self.gloss))
        .overlay(shape.strokeBorder(Color.black.opacity(0.2), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
    }

    private static let gloss = RadialGradient(
        colors: [.white.opacity(0.3), .white.opacity(0)],
        center: UnitPoint(x: 0.2, y: 0.02),
        startRadius: 0,
        endRadius: 220
    )
}

/// Colors that do not follow the theme.
enum Palette {
    static let screenFrame = Color(white: 0.45)
    static let lcdFrame = Color(white: 0.35)
    static let backlightOff = Color(red: 0.55, green: 0.58, blue: 0.55).opacity(0.55)
}
