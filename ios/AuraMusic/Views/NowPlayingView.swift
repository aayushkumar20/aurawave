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
                ZStack {
                    // Dynamic ambient glowing background
                    ambientBackground(song: song)

                    VStack(spacing: 0) {
                        // Drag Indicator Capsule & Top Bar
                        VStack(spacing: 8) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 38, height: 5)
                                .padding(.top, 10)

                            topBar(song: song)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 8)
                        }

                        if showQueueList {
                            queueListView
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            mainPlayerContent(song: song, availableHeight: geo.size.height)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .preferredColorScheme(.dark)
        }
    }

    // -------------------------------------------------------------
    // Ambient Animated Background Glow
    // -------------------------------------------------------------
    private func ambientBackground(song: Song) -> some View {
        ZStack {
            AuraColors.background.ignoresSafeArea()

            AsyncImage(url: URL(string: song.thumbnailUrl)) { img in
                img.resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 70)
                    .opacity(0.35)
            } placeholder: {
                Color.clear
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    AuraColors.background.opacity(0.3),
                    AuraColors.background.opacity(0.85),
                    AuraColors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
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
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("PLAYING FROM YOUTUBE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AuraColors.textMuted)
                    .tracking(1.4)
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
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // -------------------------------------------------------------
    // Main Player View
    // -------------------------------------------------------------
    private func mainPlayerContent(song: Song, availableHeight: CGFloat) -> some View {
        let artworkSize: CGFloat = max(180, min(availableHeight * 0.35, 290))

        return VStack(spacing: 0) {
            Spacer(minLength: 8)

            // Album Artwork with Shadow & Border
            ZStack {
                AsyncImage(url: URL(string: song.thumbnailUrl)) { img in
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    AuraColors.surfaceLight
                }
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: AuraColors.primary.opacity(0.4), radius: 26, y: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                // Playing Visualizer Badge
                if player.isPlaying {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VisualizerView(isPlaying: true, barCount: 4)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(12)
                        }
                    }
                    .frame(width: artworkSize, height: artworkSize)
                }
            }

            Spacer(minLength: 16)

            // Track Title, Artist & Action Icons Row
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AuraColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Share to Chat Button
                Button(action: {
                    onDismiss()
                    onNavigateToChat()
                }) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 17))
                        .foregroundColor(AuraColors.cyan)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }

                // Favorite Heart Button
                Button(action: {
                    player.toggleFavorite(song)
                    heartBounce = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        heartBounce = false
                    }
                }) {
                    Image(systemName: player.favorites.contains(song.id) ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(player.favorites.contains(song.id) ? AuraColors.pink : AuraColors.textMuted)
                        .scaleEffect(heartBounce ? 1.3 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: heartBounce)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 14)

            // ROCK-SOLID CUSTOM SMOOTH SEEKING SLIDER (ZERO JITTER, ZERO SNAP-BACK)
            customScrubberView
                .padding(.horizontal, 28)

            Spacer(minLength: 16)

            // Primary Playback Controls Row
            HStack(alignment: .center) {
                // Shuffle
                Button(action: { player.toggleShuffle() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(player.isShuffleEnabled ? AuraColors.cyan : AuraColors.textMuted)
                        if player.isShuffleEnabled {
                            Circle().fill(AuraColors.cyan).frame(width: 4, height: 4)
                        } else {
                            Circle().fill(Color.clear).frame(width: 4, height: 4)
                        }
                    }
                    .frame(width: 44, height: 44)
                }

                Spacer()

                // Previous
                Button(action: { player.skipPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 46, height: 46)
                }

                Spacer()

                // Glowing Hero Play / Pause
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
                            .frame(width: 70, height: 70)
                            .shadow(color: AuraColors.primary.opacity(0.55), radius: 18, y: 6)

                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
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
                        .frame(width: 46, height: 46)
                }

                Spacer()

                // Repeat Mode
                Button(action: { player.cycleRepeatMode() }) {
                    VStack(spacing: 4) {
                        Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(player.repeatMode != .off ? AuraColors.cyan : AuraColors.textMuted)
                        if player.repeatMode != .off {
                            Circle().fill(AuraColors.cyan).frame(width: 4, height: 4)
                        } else {
                            Circle().fill(Color.clear).frame(width: 4, height: 4)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)

            // Audio Output Indicator
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AuraColors.cyan)
                Text("Aura Lossless Audio • 100% Ad-Free")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AuraColors.textMuted)
            }
            .padding(.bottom, 20)
        }
    }

    // -------------------------------------------------------------
    // Rock-Solid Custom Scrubber View (100% Smooth Dragging)
    // -------------------------------------------------------------
    private var customScrubberView: some View {
        GeometryReader { scrubGeo in
            let totalWidth = scrubGeo.size.width
            let dur = max(player.duration, 1.0)
            let activeTime = isDraggingSlider ? dragSliderValue : player.currentTime
            let clampedTime = max(0, min(activeTime, dur))
            let fraction = CGFloat(clampedTime / dur)
            let fillWidth = max(0, min(fraction * totalWidth, totalWidth))

            VStack(spacing: 8) {
                // Scrubber Track
                ZStack(alignment: .leading) {
                    // Background Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 5)

                    // Active Progress Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [AuraColors.primary, AuraColors.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: 5)

                    // Glowing Scrubber Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDraggingSlider ? 18 : 12, height: isDraggingSlider ? 18 : 12)
                        .shadow(color: AuraColors.cyan.opacity(0.8), radius: isDraggingSlider ? 8 : 4)
                        .offset(x: max(0, min(fillWidth - (isDraggingSlider ? 9 : 6), totalWidth - (isDraggingSlider ? 18 : 12))))
                        .animation(.interactiveSpring(response: 0.15), value: isDraggingSlider)
                }
                .frame(height: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDraggingSlider {
                                isDraggingSlider = true
                                player.isScrubbing = true
                            }
                            let touchX = max(0, min(gesture.location.x, totalWidth))
                            let newFraction = Double(touchX / totalWidth)
                            dragSliderValue = newFraction * dur
                        }
                        .onEnded { gesture in
                            let touchX = max(0, min(gesture.location.x, totalWidth))
                            let finalFraction = Double(touchX / totalWidth)
                            let finalSec = finalFraction * dur
                            dragSliderValue = finalSec
                            player.seek(to: finalSec)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                isDraggingSlider = false
                                player.isScrubbing = false
                            }
                        }
                )

                // Time Labels
                HStack {
                    Text(formatTime(clampedTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AuraColors.textMuted)
                    Spacer()
                    let remaining = max(0, dur - clampedTime)
                    Text("-\(formatTime(remaining))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AuraColors.textMuted)
                }
            }
        }
        .frame(height: 48)
    }

    // -------------------------------------------------------------
    // Up Next Queue List View
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
