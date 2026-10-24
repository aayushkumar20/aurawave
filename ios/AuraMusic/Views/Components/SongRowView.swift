import SwiftUI

public struct SongRowView: View {
    public let song: Song
    public let isPlayingThisSong: Bool
    public let isFavorite: Bool
    public let onPlay: () -> Void
    public let onPlayNext: () -> Void
    public let onPlayLast: () -> Void
    public let onToggleFavorite: () -> Void
    public let onShareToChat: () -> Void

    public init(
        song: Song,
        isPlayingThisSong: Bool,
        isFavorite: Bool,
        onPlay: @escaping () -> Void,
        onPlayNext: @escaping () -> Void,
        onPlayLast: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void,
        onShareToChat: @escaping () -> Void
    ) {
        self.song = song
        self.isPlayingThisSong = isPlayingThisSong
        self.isFavorite = isFavorite
        self.onPlay = onPlay
        self.onPlayNext = onPlayNext
        self.onPlayLast = onPlayLast
        self.onToggleFavorite = onToggleFavorite
        self.onShareToChat = onShareToChat
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(hex: "1E2536")
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if isPlayingThisSong {
                    Color.black.opacity(0.5)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VisualizerView(isPlaying: true, barCount: 4)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isPlayingThisSong ? Color(hex: "06B6D4") : .white)
                    .lineLimit(1)
                Text("\(song.artist) • \(song.durationText)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .lineLimit(1)
            }

            Spacer()

            // Favorite Button
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? Color(hex: "F43F5E") : Color(hex: "64748B"))
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)

            // Context Menu (Play Next, Play Last, Share to Chat)
            Menu {
                Button(action: onPlayNext) {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                Button(action: onPlayLast) {
                    Label("Play Last", systemImage: "text.line.last.and.arrowtriangle.forward")
                }
                Button(action: onShareToChat) {
                    Label("Share to Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(Color(hex: "94A3B8"))
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPlayingThisSong ? Color(hex: "1E2536") : Color(hex: "131824").opacity(0.5))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onPlay)
    }
}
