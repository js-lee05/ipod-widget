import SwiftUI

/// The click wheel: circular drag rotates, clicks on the ring hit the four buttons.
struct ClickWheelView: View {
    let onRotate: (Int) -> Void
    let onButton: (WheelButton) -> Void
    let onCenter: () -> Void

    @Environment(\.style) private var style

    @State private var lastAngle: Double?
    @State private var accumulated = 0.0
    @State private var travelled = 0.0

    var body: some View {
        let face = style.colors.wheelFace
        let button = style.colors.centerFace
        return GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                // Matte ring set flush into the body: faint top shade, thin dark seam.
                Circle()
                    .fill(
                        LinearGradient(colors: [Color(face.adjusted(by: -0.04)), Color(face.adjusted(by: 0.03))], startPoint: .top, endPoint: .bottom)
                            .shadow(.inner(color: .black.opacity(0.15), radius: 2, y: 1))
                    )
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.14), lineWidth: 0.75))
                    .contentShape(Circle())
                    .gesture(rotation(center: center))
                labels
                    .allowsHitTesting(false)
                // Slightly convex button in the body color, lit from the top.
                Circle()
                    .fill(LinearGradient(colors: [Color(button.adjusted(by: 0.1)), Color(button.adjusted(by: -0.06))], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .black.opacity(0.2)], startPoint: .top, endPoint: .bottom), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                    .frame(width: Layout.centerButtonDiameter, height: Layout.centerButtonDiameter)
                    .contentShape(Circle())
                    .onTapGesture(perform: onCenter)
            }
        }
    }

    private var labels: some View {
        VStack {
            Text("MENU").font(.system(size: 10, weight: .bold))
            Spacer()
            HStack {
                Image(systemName: "backward.end.alt.fill")
                Spacer()
                Image(systemName: "forward.end.alt.fill")
            }
            Spacer()
            Image(systemName: "playpause.fill")
        }
        .font(.system(size: 10))
        .foregroundStyle(Color(style.colors.wheelLabel))
        .padding(11)
    }

    private func rotation(center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let angle = Self.angle(of: value.location, around: center)
                defer { lastAngle = angle }
                guard let last = lastAngle else { return }
                // Clockwise (decreasing math angle) scrolls down.
                var delta = last - angle
                if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
                travelled += abs(delta)
                accumulated += delta
                let steps = Int(accumulated / Input.wheelStepDegrees)
                if steps != 0 {
                    accumulated -= Double(steps) * Input.wheelStepDegrees
                    onRotate(steps)
                }
            }
            .onEnded { value in
                let moved = hypot(value.translation.width, value.translation.height)
                if travelled < Input.tapMaxDegrees && moved < Input.tapMaxTranslation {
                    onButton(Self.button(at: Self.angle(of: value.startLocation, around: center)))
                }
                lastAngle = nil
                accumulated = 0
                travelled = 0
            }
    }

    /// Angle in degrees, 0 = right, 90 = top (y axis pointing up).
    private static func angle(of point: CGPoint, around center: CGPoint) -> Double {
        atan2(center.y - point.y, point.x - center.x) * 180 / .pi
    }

    private static func button(at angle: Double) -> WheelButton {
        switch angle {
        case 45..<135: return .menu
        case -135 ..< -45: return .playPause
        case -45..<45: return .next
        default: return .previous
        }
    }
}
