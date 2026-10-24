import Foundation
import AVFoundation
import MediaPlayer
import WebKit
import Combine
import SwiftUI

public final class AudioPlayerService: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    public static let shared = AudioPlayerService()

    // Native CoreAudio Engine
    private var avPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var playerItemContext = 0
    private var isUsingAVPlayer: Bool = false

    // WebKit Fallback Player
    public var webView: WKWebView?
    private var isWebViewReady = false

    // App & Playback State
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

    private override init() {
        super.init()
        configureAudioSession()
        setupBackgroundWebView()
        setupRemoteCommandCenter()
        loadLiveTrending()
    }

    deinit {
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
        }
    }

    // -------------------------------------------------------------
    // Audio Session: Guaranteed Speaker / AirPods Output
    // -------------------------------------------------------------
    public func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[Aura Audio] Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    // -------------------------------------------------------------
    // WebKit Fallback Setup
    // -------------------------------------------------------------
    private func setupBackgroundWebView() {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        #endif
        let contentController = WKUserContentController()
        contentController.add(self, name: "audioBridge")
        config.userContentController = contentController

        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.navigationDelegate = self
        self.webView = wv

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script src="https://www.youtube.com/iframe_api"></script>
        </head>
        <body style="margin:0; background:transparent;">
        <div id="player"></div>
        <script>
        var player;
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            height: '1',
            width: '1',
            playerVars: {
              autoplay: 1,
              controls: 0,
              disablekb: 1,
              fs: 0,
              modestbranding: 1,
              playsinline: 1,
              rel: 0
            },
            events: {
              'onReady': function() {
                window.webkit.messageHandlers.audioBridge.postMessage({ type: 'READY' });
              },
              'onStateChange': function(e) {
                window.webkit.messageHandlers.audioBridge.postMessage({ type: 'STATE', state: e.data });
              }
            }
          });
          setInterval(function() {
            if (player && player.getCurrentTime) {
              window.webkit.messageHandlers.audioBridge.postMessage({
                type: 'PROGRESS',
                current: player.getCurrentTime(),
                duration: player.getDuration()
              });
            }
          }, 500);
        }
        </script>
        </body>
        </html>
        """
        wv.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case "READY":
                self.isWebViewReady = true
            case "STATE":
                if !self.isUsingAVPlayer, let state = dict["state"] as? Int {
                    if state == 1 { // Playing
                        self.isPlaying = true
                    } else if state == 2 { // Paused
                        self.isPlaying = false
                    } else if state == 0 { // Ended
                        if self.repeatMode == .one {
                            self.seek(to: 0)
                            self.webView?.evaluateJavaScript("if (player) player.playVideo();")
                        } else {
                            self.skipNext()
                        }
                    }
                }
            case "PROGRESS":
                if !self.isUsingAVPlayer {
                    if let cur = dict["current"] as? Double,
                       let dur = dict["duration"] as? Double {
                        self.currentTime = cur
                        if dur > 0 { self.duration = dur }
                        if let song = self.currentSong {
                            self.updateNowPlayingInfo(song: song)
                        }
                    }
                }
            default:
                break
            }
        }
    }

    // -------------------------------------------------------------
    // Live Trending Music Fetcher
    // -------------------------------------------------------------
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

    // -------------------------------------------------------------
    // Playback Controls (100% COMPLETE FULL SONGS WITH REAL SOUND)
    // -------------------------------------------------------------
    public func playSong(_ song: Song) {
        configureAudioSession()

        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            currentIndex = idx
        } else {
            queue.insert(song, at: 0)
            currentIndex = 0
        }

        currentSong = song
        currentTime = 0
        duration = song.durationSeconds > 0 ? song.durationSeconds : 210
        isPlaying = true
        updateNowPlayingInfo(song: song)

        // 1. First Attempt: Native direct hardware AVPlayer stream
        Task { @MainActor in
            if let streamUrlString = await YouTubeMusicEngine.shared.resolveStreamUrl(song: song),
               let streamUrl = URL(string: streamUrlString) {
                self.playWithAVPlayer(url: streamUrl, song: song)
            } else {
                // 2. Fallback: WebKit embedded YouTube Player
                self.playWithWebView(song: song)
            }
        }
    }

    private func playWithAVPlayer(url: URL, song: Song) {
        // Clean up prior player
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        avPlayer?.pause()

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )

        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = true
        self.avPlayer = player
        self.isUsingAVPlayer = true

        // Periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.isUsingAVPlayer else { return }
            let sec = time.seconds
            if !sec.isNaN && !sec.isInfinite {
                self.currentTime = sec
                if let currentItem = self.avPlayer?.currentItem {
                    let itemDur = currentItem.duration.seconds
                    if !itemDur.isNaN && !itemDur.isInfinite && itemDur > 0 {
                        self.duration = itemDur
                    }
                }
                self.updateNowPlayingInfo(song: song)
            }
        }

        player.play()
        self.isPlaying = true
    }

    private func playWithWebView(song: Song) {
        self.isUsingAVPlayer = false
        let videoId = song.id
        webView?.evaluateJavaScript("""
        if (player && player.loadVideoById) {
            player.loadVideoById('\(videoId)');
            player.playVideo();
        }
        """)
    }

    @objc private func playerItemDidReachEnd() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.repeatMode == .one {
                self.seek(to: 0)
                self.avPlayer?.play()
            } else {
                self.skipNext()
            }
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        configureAudioSession()
        if isUsingAVPlayer {
            avPlayer?.play()
        } else {
            webView?.evaluateJavaScript("if (player && player.playVideo) { player.playVideo(); }")
        }
        isPlaying = true
    }

    public func pause() {
        if isUsingAVPlayer {
            avPlayer?.pause()
        } else {
            webView?.evaluateJavaScript("if (player && player.pauseVideo) { player.pauseVideo(); }")
        }
        isPlaying = false
    }

    public func seek(to seconds: Double) {
        currentTime = seconds
        if isUsingAVPlayer {
            let targetTime = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            avPlayer?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            webView?.evaluateJavaScript("if (player && player.seekTo) { player.seekTo(\(seconds), true); }")
        }
        if let song = currentSong {
            updateNowPlayingInfo(song: song)
        }
    }

    public func skipNext() {
        guard !queue.isEmpty else { return }
        let nextIdx = isShuffleEnabled ? Int.random(in: 0..<queue.count) : (currentIndex + 1) % queue.count
        currentIndex = nextIdx
        playSong(queue[nextIdx])
    }

    public func skipPrevious() {
        guard !queue.isEmpty else { return }
        let prevIdx = currentIndex - 1 < 0 ? queue.count - 1 : currentIndex - 1
        currentIndex = prevIdx
        playSong(queue[prevIdx])
    }

    public func playNext(_ song: Song) {
        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            queue.remove(at: idx)
        }
        let insertIndex = min(currentIndex + 1, queue.count)
        queue.insert(song, at: insertIndex)
    }

    public func playLast(_ song: Song) {
        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            queue.remove(at: idx)
        }
        queue.append(song)
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
        let newPl = Playlist(
            id: "pl_" + UUID().uuidString.prefix(8),
            name: name,
            description: description,
            coverUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300",
            songs: []
        )
        playlists.append(newPl)
    }

    public func addSongToPlaylist(playlistId: String, song: Song) {
        if let idx = playlists.firstIndex(where: { $0.id == playlistId }) {
            if !playlists[idx].songs.contains(where: { $0.id == song.id }) {
                playlists[idx].songs.append(song)
            }
        }
    }

    // -------------------------------------------------------------
    // Lock-Screen Now Playing Controls
    // -------------------------------------------------------------
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
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

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: posEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlayingInfo(song: Song) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// -------------------------------------------------------------
// Invisible WebKit Background View Representable
// -------------------------------------------------------------
public struct YouTubeBackgroundPlayerView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        container.isUserInteractionEnabled = false
        container.alpha = 0.01

        if let wv = AudioPlayerService.shared.webView {
            wv.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            container.addSubview(wv)
        }

        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}
