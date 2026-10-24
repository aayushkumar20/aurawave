import SwiftUI

public struct HomeView: View {
    @ObservedObject var player = AudioPlayerService.shared
    public let onNavigateToChat: () -> Void

    public init(onNavigateToChat: @escaping () -> Void) {
        self.onNavigateToChat = onNavigateToChat
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AURA MUSIC")
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.white)
                            .tracking(1)
                        Text("Live Stream • 100% Ad-Free")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "06B6D4"))
                    }

                    Spacer()

                    Button(action: { player.loadLiveTrending() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "06B6D4"))
                            .frame(width: 32, height: 32)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "06B6D4"))
                        Text("AD-BLOCK ON")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "06B6D4"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "6366F1").opacity(0.2))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if player.isLoadingTrending && player.trendingSongs.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color(hex: "06B6D4"))
                            .scaleEffect(1.2)
                        Text("Fetching live YouTube Music charts...")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "64748B"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 250)
                } else {
                    // Featured Spotlight
                    if let featured = player.trendingSongs.first {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: featured.thumbnailUrl)) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color(hex: "131824")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                            // Gradient
                            LinearGradient(
                                colors: [Color.clear, Color(hex: "090D16").opacity(0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))

                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("REAL-TIME SPOTLIGHT")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: "06B6D4"))
                                        .tracking(1)
                                    Text(featured.title)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(featured.artist)
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "94A3B8"))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button(action: { player.playSong(featured) }) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                        .frame(width: 48, height: 48)
                                        .background(Color(hex: "6366F1"))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(18)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Quick Picks
                    if !player.trendingSongs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Live Top Picks")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(player.trendingSongs.prefix(10)) { song in
                                        VStack(alignment: .leading, spacing: 6) {
                                            AsyncImage(url: URL(string: song.thumbnailUrl)) { img in
                                                img.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Color(hex: "1E2536")
                                            }
                                            .frame(width: 130, height: 130)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))

                                            Text(song.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Text(song.artist)
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(hex: "64748B"))
                                                .lineLimit(1)
                                        }
                                        .frame(width: 130)
                                        .onTapGesture {
                                            player.playSong(song)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    // Trending on YouTube Music
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Trending YouTube Music")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)

                        ForEach(Array(player.trendingSongs.dropFirst())) { song in
                            SongRowView(
                                song: song,
                                isPlayingThisSong: player.currentSong?.id == song.id,
                                isFavorite: player.favorites.contains(song.id),
                                onPlay: { player.playSong(song) },
                                onPlayNext: { player.playNext(song) },
                                onPlayLast: { player.playLast(song) },
                                onToggleFavorite: { player.toggleFavorite(song) },
                                onShareToChat: onNavigateToChat
                            )
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer().frame(height: 100)
                }
            }
        }
        .background(Color(hex: "090D16").ignoresSafeArea())
    }
}
