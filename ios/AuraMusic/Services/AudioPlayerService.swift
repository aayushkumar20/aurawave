import Foundation
import AVFoundation
import MediaPlayer
import Combine

public final class AudioPlayerService: ObservableObject {
    public static let shared = AudioPlayerService()

    private var player: AVPlayer?
    private var timeObserverToken: Any?

    @Published public var currentSong: Song?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 1
    @Published public var queue: [Song] = []
    @Published public var currentIndex: Int = 0
    @Published public var isShuffleEnabled: Bool = false
    @Published public var repeatMode: RepeatMode = .off
    @Published public var favorites: Set<String> = []
    @Published public var playlists: [Playlist] = []
    @Published public var trendingSongs: [Song] = []
    @Published public var isLoadingTrending: Bool = true

    private init() {
        configureAudioSession()
        setupRemoteCommandCenter()
        loadLiveTrending()
    }

    public func loadLiveTrending() {
        isLoadingTrending = true
        Task { @MainActor in
            let songs = await YouTubeMusicEngine.shared.fetchTrendingTracks()
            self.trendingSongs = songs
            if self.queue.isEmpty && !songs.isEmpty {
                self.queue = songs
                self.currentSong = songs.first
            }
            self.isLoadingTrending = false
        }
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipNext()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipPrevious()
            return .success
        }
    }

    public func playSong(_ song: Song) {
        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            currentIndex = idx
        } else {
            queue.insert(song, at: 0)
            currentIndex = 0
        }

        currentSong = song
        loadAndPlay(song)
    }

    /**
     * User requirement: Play Next (inserts immediately after active track in queue)
     */
    public func playNext(_ song: Song) {
        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            queue.remove(at: idx)
        }
        let insertIndex = min(currentIndex + 1, queue.count)
        queue.insert(song, at: insertIndex)
    }

    /**
     * User requirement: Play Last (appends to end of current queue)
     */
    public func playLast(_ song: Song) {
        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            queue.remove(at: idx)
        }
        queue.append(song)
    }

    public func togglePlayPause() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if player == nil, let song = currentSong {
                playSong(song)
            } else {
                player?.play()
                isPlaying = true
            }
        }
    }

    public func seek(to seconds: Double) {
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: cmTime)
        currentTime = seconds
    }

    public func skipNext() {
        guard !queue.isEmpty else { return }
        let nextIdx = isShuffleEnabled ? Int.random(in: 0..<queue.count) : (currentIndex + 1) % queue.count
        currentIndex = nextIdx
        let nextSong = queue[nextIdx]
        currentSong = nextSong
        loadAndPlay(nextSong)
    }

    public func skipPrevious() {
        guard !queue.isEmpty else { return }
        let prevIdx = currentIndex - 1 < 0 ? queue.count - 1 : currentIndex - 1
        currentIndex = prevIdx
        let prevSong = queue[prevIdx]
        currentSong = prevSong
        loadAndPlay(prevSong)
    }

    public func toggleShuffle() {
        isShuffleEnabled.toggle()
    }

    public func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    public func toggleFavorite(_ song: Song) {
        if favorites.contains(song.id) {
            favorites.remove(song.id)
        } else {
            favorites.insert(song.id)
        }
    }

    public func createPlaylist(name: String, description: String = "") {
        let cover = currentSong?.thumbnailUrl ?? "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
        let pl = Playlist(
            id: "pl_\(Int(Date().timeIntervalSince1970))",
            name: name,
            description: description,
            coverUrl: cover,
            songs: []
        )
        playlists.append(pl)
    }

    private func loadAndPlay(_ song: Song) {
        Task { @MainActor in
            let resolvedUrl = await YouTubeMusicEngine.shared.resolveStreamUrl(song: song)
            let item = AVPlayerItem(url: resolvedUrl)

            if let token = self.timeObserverToken {
                self.player?.removeTimeObserver(token)
                self.timeObserverToken = nil
            }

            self.player = AVPlayer(playerItem: item)
            self.player?.play()
            self.isPlaying = true
            self.duration = song.durationSeconds

            // Track progress
            let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
            self.timeObserverToken = self.player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self = self else { return }
                self.currentTime = time.seconds
                if let dur = self.player?.currentItem?.duration.seconds, !dur.isNaN {
                    self.duration = dur
                }
            }

            // Track finished notification
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                if self.repeatMode == .one {
                    self.seek(to: 0)
                    self.player?.play()
                } else {
                    self.skipNext()
                }
            }

            self.updateNowPlayingInfo(song: song)
        }
    }

    private func updateNowPlayingInfo(song: Song) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = song.durationSeconds
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
