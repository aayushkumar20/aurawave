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
                // Micro Progress Bar (Smooth animated width)
                GeometryReader { geo in
                    let progress = player.duration > 0 ? max(0, min(player.currentTime / player.duration, 1.0)) : 0
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AuraColors.primary, AuraColors.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    // Album Thumbnail with ambient rounded corners
                    AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        AuraColors.surfaceLight
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )

                    // Title & Artist with Live Audio Indicator
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AuraColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Mini Visualizer (Bounces when music is playing)
                    if player.isPlaying {
                        VisualizerView(isPlaying: true, barCount: 3)
                            .frame(height: 16)
                            .padding(.trailing, 4)
                    }

                    // Play / Pause Circle Button
                    Button(action: { player.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AuraColors.primary, AuraColors.cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .shadow(color: AuraColors.primary.opacity(0.4), radius: 6, y: 2)

                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: player.isPlaying ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)

                    // Skip Next Button
                    Button(action: { player.skipNext() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AuraColors.textSecondary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AuraColors.surface.opacity(0.96))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}
