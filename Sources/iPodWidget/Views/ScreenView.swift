import IPodCore
import SwiftUI

/// The LCD: title bar plus either the menu list or the Now Playing screen.
struct ScreenView: View {
    @ObservedObject var model: AppModel
    @Environment(\.style) private var style

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4)
        VStack(spacing: 0) {
            titleBar
            Rectangle().fill(Color(style.colors.lcdText).opacity(0.5)).frame(height: 1)
            if model.showingNowPlaying {
                NowPlayingView(model: model)
            } else {
                MenuListView(page: model.navigator.current, visibleRows: model.navigator.visibleRows)
            }
        }
        .foregroundStyle(Color(style.colors.lcdText))
        .background(LinearGradient(colors: [Color(style.colors.lcdTop), Color(style.colors.lcdBottom)], startPoint: .top, endPoint: .bottom))
        .overlay(model.backlightOn ? Color.clear : Palette.backlightOff)
        .overlay(shape.fill(Color.clear.shadow(.inner(color: .black.opacity(0.45), radius: 3, y: 1.5))))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.lcdFrame, lineWidth: 1))
    }

    private var titleBar: some View {
        ZStack {
            Text(model.screenTitle)
                .font(style.font(13, .bold))
                .lineLimit(1)
                .padding(.horizontal, 36)
            HStack {
                if model.nowPlaying?.state == .playing {
                    Image(systemName: "play.fill").font(.system(size: 9))
                }
                Spacer()
                Image(systemName: "battery.100").font(.system(size: 13))
            }
            .padding(.horizontal, 6)
        }
        .frame(height: Layout.titleBarHeight)
    }
}

struct MenuListView: View {
    let page: MenuPage
    let visibleRows: Int
    @Environment(\.style) private var style

    var body: some View {
        VStack(spacing: 0) {
            if page.items.isEmpty {
                Text("No items").font(style.font(13, .semibold)).frame(maxHeight: .infinity)
            } else {
                let end = min(page.top + visibleRows, page.items.count)
                ForEach(page.top..<end, id: \.self) { i in
                    row(page.items[i], selected: i == page.selection)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ item: MenuItem, selected: Bool) -> some View {
        HStack {
            Text(item.title).lineLimit(1)
            Spacer(minLength: 4)
            if item.showsChevron { Image(systemName: "chevron.right").font(style.font(11, .bold)) }
        }
        .font(style.font(14, .bold))
        .padding(.horizontal, 7)
        .frame(height: Layout.rowHeight)
        .foregroundStyle(selected ? Color(style.colors.highlightText) : Color(style.colors.lcdText))
        .background(
            selected
                ? LinearGradient(colors: [Color(style.colors.highlightTop), Color(style.colors.highlightBottom)], startPoint: .top, endPoint: .bottom)
                : nil
        )
    }
}

struct NowPlayingView: View {
    @ObservedObject var model: AppModel
    @Environment(\.style) private var style

    var body: some View {
        Group {
            if let status = model.nowPlaying, status.trackID != nil {
                content(status)
            } else {
                Text(model.notice ?? "Nothing playing")
                    .font(style.font(12, .semibold))
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func content(_ status: NowPlaying) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let index = status.index, let count = status.count {
                Text("\(index) of \(count)").font(style.font(10, .semibold))
            }
            HStack(alignment: .top, spacing: 8) {
                if let artwork = model.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: Layout.artworkSize, height: Layout.artworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.title).font(style.font(13, .bold))
                    Text(status.artist).font(style.font(11, .semibold))
                    Text(status.album).font(style.font(11))
                }
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            if model.volumeVisibleUntil > Date() {
                bar(fraction: Double(status.volume) / 100, leading: "speaker.fill", trailing: "speaker.wave.3.fill")
            } else if status.duration > 0 {
                progress(status)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func progress(_ status: NowPlaying) -> some View {
        VStack(spacing: 2) {
            meter(status.position / status.duration)
            HStack {
                Text(Self.time(status.position))
                Spacer()
                Text("-" + Self.time(status.duration - status.position))
            }
            .font(style.font(10, .semibold).monospacedDigit())
        }
    }

    private func bar(fraction: Double, leading: String, trailing: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: leading)
            meter(fraction)
            Image(systemName: trailing)
        }
        .font(.system(size: 9))
    }

    private func meter(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(style.colors.lcdTop))
                Rectangle()
                    .fill(LinearGradient(colors: [Color(style.colors.highlightTop), Color(style.colors.highlightBottom)], startPoint: .top, endPoint: .bottom))
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
            .overlay(Rectangle().stroke(Color(style.colors.lcdText).opacity(0.6), lineWidth: 1))
        }
        .frame(height: 8)
    }

    private static func time(_ seconds: Double) -> String {
        let s = max(Int(seconds), 0)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
