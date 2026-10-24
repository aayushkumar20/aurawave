import Foundation
import WebKit
import MediaPlayer
import Combine

public final class AudioPlayerService: NSObject, ObservableObject, WKNavigationDelegate, WKScriptMessageHandler {
    public static let shared = AudioPlayerService()

    private var webView: WKWebView?
    private var isWebViewReady = false

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
        setupBackgroundPlayer()
        configureAudioSession()
        setupRemoteCommandCenter()
        loadLiveTrending()
    }

    private func setupBackgroundPlayer() {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        #endif
        let contentController = WKUserContentController()
        contentController.add(self, name: "audioBridge")
        config.userContentController = contentController

        let wv = WKWebView(frame: .zero, configuration: config)
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
            height: '100%',
            width: '100%',
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
                if let song = self.currentSong {
                    self.playSong(song)
                }
            case "STATE":
                if let state = dict["state"] as? Int {
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
                if let cur = dict["current"] as? Double,
                   let dur = dict["duration"] as? Double {
                    self.currentTime = cur
                    if dur > 0 { self.duration = dur }
                    if let song = self.currentSong {
                        self.updateNowPlayingInfo(song: song)
                    }
                }
            default:
                break
            }
        }
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

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: posEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }

    /**
     * Plays 100% COMPLETE Full YouTube Song
     */
    public func playSong(_ song: Song) {
        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            currentIndex = idx
        } else {
            queue.insert(song, at: 0)
            currentIndex = 0
        }

        currentSong = song
        let videoId = song.id
        webView?.evaluateJavaScript("if (player && player.loadVideoById) { player.loadVideoById('\(videoId)'); player.playVideo(); }")
        isPlaying = true
        duration = song.durationSeconds
        updateNowPlayingInfo(song: song)
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

    public func togglePlayPause() {
        if isPlaying {
            webView?.evaluateJavaScript("if (player && player.pauseVideo) { player.pauseVideo(); }")
            isPlaying = false
        } else {
            webView?.evaluateJavaScript("if (player && player.playVideo) { player.playVideo(); }")
            isPlaying = true
        }
    }

    /**
     * Exact seeking across full song (e.g. at 1 min)
     */
    public func seek(to seconds: Double) {
        currentTime = seconds
        webView?.evaluateJavaScript("if (player && player.seekTo) { player.seekTo(\(seconds), true); }")
    }

    public func skipNext() {
        guard !queue.isEmpty else { return }
        let nextIdx = isShuffleEnabled ? Int.random(in: 0..<queue.count) : (currentIndex + 1) % queue.count
        currentIndex = nextIdx
        let nextSong = queue[nextIdx]
        playSong(nextSong)
    }

    public func skipPrevious() {
        guard !queue.isEmpty else { return }
        let prevIdx = currentIndex - 1 < 0 ? queue.count - 1 : currentIndex - 1
        currentIndex = prevIdx
        let prevSong = queue[prevIdx]
        playSong(prevSong)
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

    private func updateNowPlayingInfo(song: Song) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = song.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
