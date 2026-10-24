import SwiftUI

public struct LibraryView: View {
    @ObservedObject var player = AudioPlayerService.shared

    @State private var showCreateDialog: Bool = false
    @State private var newPlaylistName: String = ""
    @State private var newPlaylistDesc: String = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Your Library")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { showCreateDialog = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "06B6D4"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "131824"))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Favorite Songs Hero Card
                Button(action: {
                    let favs = (player.queue + player.trendingSongs).filter { player.favorites.contains($0.id) }
                    if let first = favs.first {
                        player.playSong(first)
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20))
                                Text("Favorite Songs")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("\(player.favorites.count) songs saved offline & ad-free")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.25))
                            .clipShape(Circle())
                    }
                    .padding(18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "EC4899"), Color(hex: "6366F1")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                // Playlists List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Playlists")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    ForEach(player.playlists) { playlist in
                        HStack(spacing: 14) {
                            AsyncImage(url: URL(string: playlist.coverUrl)) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color(hex: "1E2536")
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("\(playlist.songs.count) tracks • \(playlist.description)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "94A3B8"))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button(action: {
                                if let first = playlist.songs.first {
                                    player.playSong(first)
                                }
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: "06B6D4"))
                            }
                        }
                        .padding(12)
                        .background(Color(hex: "131824"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                    }
                }

                Spacer().frame(height: 100)
            }
        }
        .background(Color(hex: "090D16").ignoresSafeArea())
        .alert("Create New Playlist", isPresented: $showCreateDialog) {
            TextField("Playlist Name", text: $newPlaylistName)
            TextField("Description (Optional)", text: $newPlaylistDesc)
            Button("Create") {
                if !newPlaylistName.isEmpty {
                    player.createPlaylist(name: newPlaylistName, description: newPlaylistDesc)
                    newPlaylistName = ""
                    newPlaylistDesc = ""
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
