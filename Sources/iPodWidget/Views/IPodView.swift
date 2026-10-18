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
        let colors = style.colors
        let shape = RoundedRectangle(cornerRadius: Layout.bodyCornerRadius, style: .continuous)
        let bezel = RoundedRectangle(cornerRadius: 5, style: .continuous)
        VStack(spacing: Layout.screenToWheelSpacing) {
            ScreenView(model: model)
                .frame(height: Layout.screenHeight)
                .padding(Layout.bezelWidth)
                .background(bezel.fill(LinearGradient(colors: [Palette.bezelTop, Palette.bezelBottom], startPoint: .top, endPoint: .bottom)))
                // One sheet of glass covers bezel and screen: sharp diagonal glare and a thin bright edge.
                .overlay(GlareShape().fill(Self.glare).clipShape(bezel).allowsHitTesting(false))
                .overlay(bezel.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .overlay(bezel.inset(by: -1).strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
            ClickWheelView(
                onRotate: model.rotate,
                onButton: model.press,
                onCenter: model.select
            )
            .frame(width: Layout.wheelDiameter, height: Layout.wheelDiameter)
            Spacer(minLength: 0)
        }
        .padding(Layout.bodyPadding)
        .frame(width: Layout.deviceSize.width, height: Layout.deviceSize.height)
        .background(
            // Anodized aluminum: soft vertical sheen, darker rounded sides, bright top bevel, drop shadow.
            shape
                .fill(LinearGradient(colors: [Color(colors.bodyTop), Color(colors.bodyBottom)], startPoint: .top, endPoint: .bottom))
                .overlay(shape.fill(Self.sideShade))
                .overlay(shape.fill(Self.specular))
                .overlay(shape.strokeBorder(Self.bevel, lineWidth: 1.5))
                .overlay(shape.strokeBorder(Color(colors.bodyEdge), lineWidth: 0.75))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
        )
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { _ in mover.drag() }
                .onEnded { _ in mover.end() }
        )
        .padding(Layout.shadowMargin)
        .environment(\.style, style)
    }

    private static let specular = RadialGradient(
        colors: [.white.opacity(0.22), .white.opacity(0)],
        center: UnitPoint(x: 0.2, y: 0),
        startRadius: 0,
        endRadius: 260
    )

    /// Rounded sides of the body catch less light than its face.
    private static let sideShade = LinearGradient(
        stops: [
            .init(color: .black.opacity(0.10), location: 0),
            .init(color: .clear, location: 0.12),
            .init(color: .clear, location: 0.88),
            .init(color: .black.opacity(0.12), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Thin highlight along the top edge fading out toward the bottom.
    private static let bevel = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.85), location: 0),
            .init(color: .white.opacity(0.15), location: 0.08),
            .init(color: .black.opacity(0.15), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private static let glare = LinearGradient(
        colors: [.white.opacity(0.24), .white.opacity(0.07)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}

/// Upper-right wedge of the cover glass that reflects light.
private struct GlareShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.width * 0.56, y: 0))
            p.addLine(to: CGPoint(x: rect.width, y: 0))
            p.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.74))
            p.closeSubpath()
        }
    }
}

/// Colors that do not follow the theme.
enum Palette {
    static let bezelTop = Color(white: 0.13)
    static let bezelBottom = Color(white: 0.03)
    static let lcdFrame = Color(white: 0.35)
    static let backlightOff = Color(red: 0.55, green: 0.58, blue: 0.55).opacity(0.55)
}
