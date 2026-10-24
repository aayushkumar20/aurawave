import SwiftUI

public struct NowPlayingView: View {
    @ObservedObject var player = AudioPlayerService.shared
    public let onDismiss: () -> Void
    public let onNavigateToChat: () -> Void

    @State private var showQueueList: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragSliderValue: Double = 0
    @State private var heartBounce: Bool = false

    public init(onDismiss: @escaping () -> Void, onNavigateToChat: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.onNavigateToChat = onNavigateToChat
    }

    public var body: some View {
        if let song = player.currentSong {
            GeometryReader { geo in
                let screenWidth = geo.size.width
                let screenHeight = geo.size.height

                ZStack {
                    // Ambient Blurred Artwork Background (CLIPPED TO EXACT SCREEN BOUNDS)
                    ambientBackground(song: song, width: screenWidth, height: screenHeight)

                    VStack(spacing: 0) {
                        // Top Drag Indicator Bar
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 36, height: 4)
                            .padding(.top, 8)
                            .padding(.bottom, 6)

                        // Top Navigation Bar
                        topBar(song: song)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        if showQueueList {
                            queueListView
                        } else {
                            mainPlayerContent(song: song, width: screenWidth, height: screenHeight)
                        }
                    }
                    .frame(width: screenWidth, height: screenHeight)
                }
                .frame(width: screenWidth, height: screenHeight)
                .clipped()
            }
            .preferredColorScheme(.dark)
        }
    }

    // -------------------------------------------------------------
    // Ambient Background (Strictly Clipped, No Horizontal Overflow)
    // -------------------------------------------------------------
    private func ambientBackground(song: Song, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            AuraColors.background

            AsyncImage(url: URL(string: song.thumbnailUrl)) { img in
                img.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .blur(radius: 60)
                    .opacity(0.3)
            } placeholder: {
                Color.clear
            }

            LinearGradient(
                colors: [
                    AuraColors.background.opacity(0.35),
                    AuraColors.background.opacity(0.85),
                    AuraColors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: height)
        .clipped()
        .ignoresSafeArea()
    }

    // -------------------------------------------------------------
    // Top Bar
    // -------------------------------------------------------------
    private func topBar(song: Song) -> some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("NOW PLAYING")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AuraColors.textMuted)
                    .tracking(1.5)
                Text(showQueueList ? "Up Next Queue" : song.album)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AuraColors.cyan)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showQueueList.toggle()
                }
            }) {
                Image(systemName: showQueueList ? "music.note" : "list.bullet")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(showQueueList ? AuraColors.cyan : .white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    // -------------------------------------------------------------
    // Main Player Content (Pixel-Perfect, Perfectly Centered)
    // -------------------------------------------------------------
    private func mainPlayerContent(song: Song, width: CGFloat, height: CGFloat) -> some View {
        // Dynamically compute artwork size so it NEVER pushes controls off screen
        let maxArtSize = min(width - 80, height * 0.33)
        let artworkSize: CGFloat = max(160, min(maxArtSize, 260))

        return VStack(spacing: 0) {
            Spacer(minLength: 6)

            // Centered Album Artwork
            ZStack {
                AsyncImage(url: URL(string: song.thumbnailUrl)) { img in
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    AuraColors.surfaceLight
                }
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: AuraColors.primary.opacity(0.45), radius: 24, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

                // Playing Visualizer Badge
                if player.isPlaying {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VisualizerView(isPlaying: true, barCount: 4)
                                .padding(6)
                                .background(Color.black.opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .padding(10)
                        }
                    }
                    .frame(width: artworkSize, height: artworkSize)
                }
            }
            .frame(width: width)

            Spacer(minLength: 12)

            // Track Title, Artist, & Actions
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AuraColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Share to Chat
                Button(action: {
                    onDismiss()
                    onNavigateToChat()
                }) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AuraColors.cyan)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }

                // Favorite
                Button(action: {
                    player.toggleFavorite(song)
                    heartBounce = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        heartBounce = false
                    }
                }) {
                    Image(systemName: player.favorites.contains(song.id) ? "heart.fill" : "heart")
                        .font(.system(size: 19))
                        .foregroundColor(player.favorites.contains(song.id) ? AuraColors.pink : AuraColors.textMuted)
                        .scaleEffect(heartBounce ? 1.25 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: heartBounce)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .frame(width: width)

            Spacer(minLength: 10)

            // Smooth Seeking Scrubber
            customScrubberView(width: width - 48)
                .frame(width: width - 48)

            Spacer(minLength: 12)

            // Playback Controls Row
            HStack(alignment: .center) {
                // Shuffle
                Button(action: { player.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(player.isShuffleEnabled ? AuraColors.cyan : AuraColors.textMuted)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Previous
                Button(action: { player.skipPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Large Glowing Play / Pause Button
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
                            .frame(width: 66, height: 66)
                            .shadow(color: AuraColors.primary.opacity(0.55), radius: 16, y: 6)

                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Next
                Button(action: { player.skipNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Repeat Mode
                Button(action: { player.cycleRepeatMode() }) {
                    Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(player.repeatMode != .off ? AuraColors.cyan : AuraColors.textMuted)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 24)
            .frame(width: width)

            Spacer(minLength: 14)

            // Audio Quality Badge
            HStack(spacing: 5) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AuraColors.cyan)
                Text("Aura Live Music • 100% Ad-Free")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AuraColors.textMuted)
            }
            .padding(.bottom, 16)
        }
        .frame(width: width)
    }

    // -------------------------------------------------------------
    // Custom Scrubber View (Bound to Exact Explicit Width)
    // -------------------------------------------------------------
    private func customScrubberView(width: CGFloat) -> some View {
        let dur = max(player.duration, 1.0)
        let activeTime = isDraggingSlider ? dragSliderValue : player.currentTime
        let clampedTime = max(0, min(activeTime, dur))
        let fraction = CGFloat(clampedTime / dur)
        let fillWidth = max(0, min(fraction * width, width))

        return VStack(spacing: 6) {
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: width, height: 4)

                // Active Progress Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [AuraColors.primary, AuraColors.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth, height: 4)

                // Scrubber Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: isDraggingSlider ? 16 : 12, height: isDraggingSlider ? 16 : 12)
                    .shadow(color: AuraColors.cyan.opacity(0.8), radius: isDraggingSlider ? 6 : 3)
                    .offset(x: max(0, min(fillWidth - (isDraggingSlider ? 8 : 6), width - (isDraggingSlider ? 16 : 12))))
            }
            .frame(width: width, height: 26)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDraggingSlider {
                            isDraggingSlider = true
                            player.isScrubbing = true
                        }
                        let touchX = max(0, min(gesture.location.x, width))
                        let newFraction = Double(touchX / width)
                        dragSliderValue = newFraction * dur
                    }
                    .onEnded { gesture in
                        let touchX = max(0, min(gesture.location.x, width))
                        let finalFraction = Double(touchX / width)
                        let finalSec = finalFraction * dur
                        dragSliderValue = finalSec
                        player.seek(to: finalSec)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isDraggingSlider = false
                            player.isScrubbing = false
                        }
                    }
            )

            // Current Time & Duration Labels
            HStack {
                Text(formatTime(clampedTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(AuraColors.textMuted)
                Spacer()
                Text(formatTime(dur))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(AuraColors.textMuted)
            }
            .frame(width: width)
        }
    }

    // -------------------------------------------------------------
    // Queue List View
    // -------------------------------------------------------------
    private var queueListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up Next Queue")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(player.queue.count) songs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AuraColors.cyan)
            }
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
                .padding(.bottom, 40)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        let mins = s / 60
        let secs = s % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
