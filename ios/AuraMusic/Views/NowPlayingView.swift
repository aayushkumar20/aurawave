import SwiftUI

public struct NowPlayingView: View {
    @ObservedObject var player = AudioPlayerService.shared
    public let onDismiss: () -> Void
    public let onNavigateToChat: () -> Void

    @State private var showQueueList: Bool = false

    public init(onDismiss: @escaping () -> Void, onNavigateToChat: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.onNavigateToChat = onNavigateToChat
    }

    public var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 20) {
                // Header Bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("PLAYING FROM YOUTUBE MUSIC")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "64748B"))
                            .tracking(1)
                        Text(showQueueList ? "Up Next Queue" : song.album)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "06B6D4"))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: { showQueueList.toggle() }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(showQueueList ? Color(hex: "06B6D4") : Color(hex: "94A3B8"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if showQueueList {
                    // Queue List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Up Next (\(player.queue.count) songs)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)

                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(player.queue.enumerated()), id: \.offset) { index, item in
                                    SongRowView(
                                        song: item,
                                        isPlayingThisSong: index == player.currentIndex,
                                        isFavorite: player.favorites.contains(item.id),
                                        onPlay: { player.playSong(item) },
                                        onPlayNext: { player.playNext(item) },
                                        onPlayLast: { player.playLast(item) },
                                        onToggleFavorite: { player.toggleFavorite(item) },
                                        onShareToChat: {
                                            onDismiss()
                                            onNavigateToChat()
                                        }
                                    )
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                } else {
                    // Big Artwork
                    AsyncImage(url: URL(string: song.thumbnailUrl)) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(hex: "131824")
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: Color(hex: "6366F1").opacity(0.4), radius: 24, y: 12)
                    .padding(.horizontal, 24)

                    // Song Info & Actions
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(song.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "94A3B8"))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: onNavigateToChat) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "06B6D4"))
                        }
                        .padding(.trailing, 8)

                        Button(action: { player.toggleFavorite(song) }) {
                            Image(systemName: player.favorites.contains(song.id) ? "heart.fill" : "heart")
                                .font(.system(size: 24))
                                .foregroundColor(player.favorites.contains(song.id) ? Color(hex: "F43F5E") : Color(hex: "64748B"))
                        }
                    }
                    .padding(.horizontal, 24)

                    // Audio Visualizer
                    VisualizerView(isPlaying: player.isPlaying, barCount: 16)
                        .padding(.vertical, 4)

                    // Progress Slider
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { player.currentTime },
                                set: { player.seek(to: $0) }
                            ),
                            in: 0...max(player.duration, 1)
                        )
                        .tint(Color(hex: "06B6D4"))

                        HStack {
                            Text(formatTime(player.currentTime))
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "64748B"))
                            Spacer()
                            Text(formatTime(player.duration))
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "64748B"))
                        }
                    }
                    .padding(.horizontal, 24)

                    // Controls Row
                    HStack {
                        // Shuffle
                        Button(action: { player.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 18))
                                .foregroundColor(player.isShuffleEnabled ? Color(hex: "06B6D4") : Color(hex: "64748B"))
                        }

                        Spacer()

                        // Previous
                        Button(action: { player.skipPrevious() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // Play / Pause
                        Button(action: { player.togglePlayPause() }) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .frame(width: 68, height: 68)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "6366F1"), Color(hex: "06B6D4")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: Color(hex: "6366F1").opacity(0.5), radius: 16)
                        }

                        Spacer()

                        // Next
                        Button(action: { player.skipNext() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // Repeat
                        Button(action: { player.cycleRepeatMode() }) {
                            Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.system(size: 18))
                                .foregroundColor(player.repeatMode != .off ? Color(hex: "06B6D4") : Color(hex: "64748B"))
                        }
                    }
                    .padding(.horizontal, 28)
                }

                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "1E2536"), Color(hex: "090D16"), Color(hex: "090D16")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        let mins = s / 60
        let secs = s % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
