import IPodCore
import SwiftUI

/// Settings window content: body color and screen color.
struct CustomizeView: View {
    private static let swatchSize: CGFloat = 26

    @ObservedObject var store: ThemeStore

    var body: some View {
        Form {
            Section("iPod Color") {
                colorRow(presets: ThemePresets.body, color: $store.theme.bodyColor)
            }
            Section("Screen Color") {
                colorRow(presets: ThemePresets.screen, color: $store.theme.screenColor)
            }
            Button("Reset to Default", action: store.reset)
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func colorRow(presets: [ThemePreset], color: Binding<IPodCore.RGBColor>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.name) { preset in
                    Button { color.wrappedValue = preset.color } label: {
                        Circle()
                            .fill(Color(preset.color))
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1))
                            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: color.wrappedValue == preset.color ? 3 : 0))
                            .frame(width: Self.swatchSize, height: Self.swatchSize)
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                }
            }
            ColorPicker("Custom", selection: Binding(
                get: { Color(color.wrappedValue) },
                set: { if let rgb = IPodCore.RGBColor($0) { color.wrappedValue = rgb } }
            ), supportsOpacity: false)
        }
    }
}
