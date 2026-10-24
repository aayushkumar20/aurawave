import SwiftUI

public struct PlayerBarView: View {
    @ObservedObject var player = AudioPlayerService.shared
    public let onTap: () -> Void

    public init(onTap: @escaping () -> Void) {
        self.onTap = onTap
    }

    public var body: some View {
        if let song = player.currentSong {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    let progress = player.duration > 0 ? (player.currentTime / player.duration) : 0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(hex: "1E2536"))
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "06B6D4"), Color(hex: "6366F1")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    // Thumbnail
                    AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color(hex: "1E2536")
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "94A3B8"))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Play / Pause Button
                    Button(action: { player.togglePlayPause() }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "6366F1"))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    // Skip Next Button
                    Button(action: { player.skipNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "94A3B8"))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "131824"))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.4), radius: 10, y: -4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}
