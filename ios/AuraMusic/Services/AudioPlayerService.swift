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
    private var isUsingAVPlayer: Bool = false

    // WebKit Real-Time YouTube Audio Engine
    public var webView: WKWebView?
    private var pendingSongId: String? = nil

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

    // Guard to prevent slider fighting during user drag
    public var isScrubbing: Bool = false

    private override init() {
        super.init()
        configureAudioSession()
        setupBackgroundWebView()
        setupRemoteCommandCenter()
        loadLiveTrending()
    }

    // -------------------------------------------------------------
    // Guaranteed Audio Session Configuration
    // -------------------------------------------------------------
    public func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[Aura Audio] Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    // -------------------------------------------------------------
    // WebKit Setup
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

        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 240), configuration: config)
        wv.navigationDelegate = self
        wv.isOpaque = false
        wv.backgroundColor = .black
        self.webView = wv
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case "READY":
                self.configureAudioSession()
                self.play()
            case "STATE":
                if let state = dict["state"] as? Int {
                    if state == 1 { // Playing
                        self.isPlaying = true
                        self.configureAudioSession()
                    } else if state == 2 { // Paused
                        self.isPlaying = false
                    } else if state == 0 { // Ended
                        if self.repeatMode == .one {
                            self.seek(to: 0)
                            self.play()
                        } else {
                            self.skipNext()
                        }
                    }
                }
            case "PROGRESS":
                if !self.isScrubbing {
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

        // Stop AVPlayer if running
        avPlayer?.pause()
        isUsingAVPlayer = false

        // Load and play video in WebKit audio engine
        loadYouTubeVideo(videoId: song.id)
    }

    private func loadYouTubeVideo(videoId: String) {
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          * { margin:0; padding:0; box-sizing:border-box; }
          html, body { width:100%; height:100%; background:#000; overflow:hidden; }
          iframe { width:100%; height:100%; border:0; }
        </style>
        </head>
        <body>
        <iframe id="yt" src="https://www.youtube.com/embed/\(videoId)?autoplay=1&playsinline=1&controls=0&enablejsapi=1&origin=https://www.youtube.com" allow="autoplay; encrypted-media"></iframe>
        <script>
        window.addEventListener('message', function(event) {
          try {
            var data = JSON.parse(event.data);
            if (data.event === 'onReady') {
              window.webkit.messageHandlers.audioBridge.postMessage({ type: 'READY' });
            } else if (data.event === 'infoDelivery' && data.info) {
              if (typeof data.info.playerState !== 'undefined') {
                window.webkit.messageHandlers.audioBridge.postMessage({ type: 'STATE', state: data.info.playerState });
              }
              if (typeof data.info.currentTime !== 'undefined') {
                window.webkit.messageHandlers.audioBridge.postMessage({
                  type: 'PROGRESS',
                  current: data.info.currentTime,
                  duration: data.info.duration || 0
                });
              }
            }
          } catch(e) {}
        });

        var frame = document.getElementById('yt');
        function initPlayer() {
          try {
            frame.contentWindow.postMessage(JSON.stringify({ event: 'listening', id: 1 }), '*');
            frame.contentWindow.postMessage(JSON.stringify({ event: 'command', func: 'unMute', args: [] }), '*');
            frame.contentWindow.postMessage(JSON.stringify({ event: 'command', func: 'setVolume', args: [100] }), '*');
            frame.contentWindow.postMessage(JSON.stringify({ event: 'command', func: 'playVideo', args: [] }), '*');
          } catch(e) {}
        }
        frame.onload = function() {
          setTimeout(initPlayer, 250);
          setTimeout(initPlayer, 800);
        };
        </script>
        </body>
        </html>
        """
        webView?.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube.com"))
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
        let js = "document.getElementById('yt').contentWindow.postMessage(JSON.stringify({event:'command',func:'playVideo',args:[]}), '*');"
        webView?.evaluateJavaScript(js)
        isPlaying = true
    }

    public func pause() {
        let js = "document.getElementById('yt').contentWindow.postMessage(JSON.stringify({event:'command',func:'pauseVideo',args:[]}), '*');"
        webView?.evaluateJavaScript(js)
        isPlaying = false
    }

    public func seek(to seconds: Double) {
        currentTime = seconds
        let js = "document.getElementById('yt').contentWindow.postMessage(JSON.stringify({event:'command',func:'seekTo',args:[\(seconds), true]}), '*');"
        webView?.evaluateJavaScript(js)
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
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }

    public func toggleFavorite(_ song: Song) {
        if favorites.contains(song.id) {
            favorites.remove(song.id)
        } else {
            favorites.insert(song.id)
        }
    }

    public func isFavorite(_ songId: String) -> Bool {
        return favorites.contains(songId)
    }

    public func createPlaylist(name: String, description: String = "") {
        let cover = currentSong?.thumbnailUrl ?? "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
        let newPl = Playlist(
            id: "pl_\(Int(Date().timeIntervalSince1970 * 1000))",
            name: name,
            description: description,
            coverUrl: cover,
            songs: []
        )
        playlists.append(newPl)
    }

    public func addSongToPlaylist(playlistId: String, song: Song) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        if !playlists[idx].songs.contains(where: { $0.id == song.id }) {
            playlists[idx].songs.append(song)
        }
    }

    // -------------------------------------------------------------
    // Lock Screen & Control Center Remote Controls
    // -------------------------------------------------------------
    private func setupRemoteCommandCenter() {
        let rcc = MPRemoteCommandCenter.shared()

        rcc.playCommand.isEnabled = true
        rcc.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        rcc.pauseCommand.isEnabled = true
        rcc.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        rcc.togglePlayPauseCommand.isEnabled = true
        rcc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        rcc.nextTrackCommand.isEnabled = true
        rcc.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipNext()
            return .success
        }

        rcc.previousTrackCommand.isEnabled = true
        rcc.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipPrevious()
            return .success
        }

        rcc.changePlaybackPositionCommand.isEnabled = true
        rcc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
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
// WebKit Background View Representable (100% Opacity to Prevent Throttling)
// -------------------------------------------------------------
public struct YouTubeBackgroundPlayerView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        container.isUserInteractionEnabled = false

        if let wv = AudioPlayerService.shared.webView {
            wv.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
            wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(wv)
        }

        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}
