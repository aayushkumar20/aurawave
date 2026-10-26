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
    private var isWebViewReady: Bool = false
    private var queuedVideoId: String? = nil

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

    // Native Silent Audio Keep-Alive Loop for 100% Lock Screen & Background Playback
    private var keepAlivePlayer: AVAudioPlayer?
    private var isUserInitiatedPause: Bool = false
    private var pausedByInterruption: Bool = false

    private override init() {
        super.init()
        configureAudioSession()
        setupKeepAliveAudio()
        setupAudioObservers()
        setupBackgroundWebView()
        setupRemoteCommandCenter()
        loadLiveTrending()
    }

    // -------------------------------------------------------------
    // Audio Session: Industry-Standard Exclusive Playback (Spotify / Apple Music)
    // -------------------------------------------------------------
    public func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                policy: .default,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            print("[Aura Audio] Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    private func setupKeepAliveAudio() {
        // Generate an in-memory 1-second silent stereo PCM WAV buffer
        let sampleRate: Double = 44100.0
        let duration: Double = 1.0
        let numSamples = Int(sampleRate * duration)
        let numChannels: Int16 = 2
        let bitsPerSample: Int16 = 16
        let byteRate = Int32(sampleRate * Double(numChannels * (bitsPerSample / 8)))
        let blockAlign = Int16(numChannels * (bitsPerSample / 8))
        let dataSize = Int32(numSamples * Int(blockAlign))
        let chunkSize = 36 + dataSize

        var wavData = Data()
        wavData.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        var cs = chunkSize.littleEndian
        wavData.append(Data(bytes: &cs, count: 4))
        wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        wavData.append(contentsOf: [0x66, 0x6d, 0x74, 0x20]) // "fmt "
        var subchunk1Size: Int32 = 16
        wavData.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat: Int16 = 1 // PCM
        wavData.append(Data(bytes: &audioFormat, count: 2))
        var nc = numChannels.littleEndian
        wavData.append(Data(bytes: &nc, count: 2))
        var sr = Int32(sampleRate).littleEndian
        wavData.append(Data(bytes: &sr, count: 4))
        var br = byteRate.littleEndian
        wavData.append(Data(bytes: &br, count: 4))
        var ba = blockAlign.littleEndian
        wavData.append(Data(bytes: &ba, count: 2))
        var bps = bitsPerSample.littleEndian
        wavData.append(Data(bytes: &bps, count: 2))
        wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        var ds = dataSize.littleEndian
        wavData.append(Data(bytes: &ds, count: 4))
        wavData.append(Data(count: Int(dataSize)))

        do {
            let player = try AVAudioPlayer(data: wavData)
            player.numberOfLoops = -1 // Infinite loop
            player.volume = 0.01 // Minimal non-zero volume so CoreAudio never sleeps
            self.keepAlivePlayer = player
        } catch {
            print("[Aura Audio] Failed to create keepAlivePlayer: \(error)")
        }
    }

    // -------------------------------------------------------------
    // Audio Focus & Interruption Listeners (Matches Apple Music & Spotify)
    // -------------------------------------------------------------
    private func setupAudioObservers() {
        #if os(iOS)
        let nc = NotificationCenter.default

        // 1. Audio Session Interruption: phone calls, Siri, Camera recording, external apps taking exclusive focus
        nc.addObserver(
            self,
            selector: #selector(handleAudioInterruption(notification:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // 2. Secondary Audio Hint: Instagram Reels, TikTok, WhatsApp status videos, external audio
        nc.addObserver(
            self,
            selector: #selector(handleSecondaryAudioHint(notification:)),
            name: AVAudioSession.silenceSecondaryAudioHintNotification,
            object: AVAudioSession.sharedInstance()
        )

        // 3. Audio Route Change: AirPods disconnected, headphone unplugged
        nc.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(notification:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        #endif
    }

    @objc private func handleAudioInterruption(notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch interruptionType {
            case .began:
                print("[Aura Audio] Audio interruption began (phone call / Siri / external media)")
                if self.isPlaying {
                    self.pausedByInterruption = true
                    self.pauseInternal()
                }
            case .ended:
                print("[Aura Audio] Audio interruption ended")
                guard self.pausedByInterruption else { return }
                self.pausedByInterruption = false

                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        print("[Aura Audio] Resuming audio after interruption")
                        self.playInternal()
                    }
                }
            @unknown default:
                break
            }
        }
        #endif
    }

    @objc private func handleSecondaryAudioHint(notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt,
              let hintType = AVAudioSession.SilenceSecondaryAudioHintType(rawValue: typeValue) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch hintType {
            case .begin:
                print("[Aura Audio] Secondary audio hint began (external video/status playing) -> pausing")
                if self.isPlaying {
                    self.pausedByInterruption = true
                    self.pauseInternal()
                }
            case .end:
                print("[Aura Audio] Secondary audio hint ended -> resuming")
                if self.pausedByInterruption {
                    self.pausedByInterruption = false
                    self.playInternal()
                }
            @unknown default:
                break
            }
        }
        #endif
    }

    @objc private func handleAudioRouteChange(notification: Notification) {
        #if os(iOS)
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            // E.g., AirPods disconnected or headphone unplugged -> pause automatically like Spotify & Apple Music
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.isPlaying {
                    print("[Aura Audio] Audio route unavailable (AirPods disconnected) -> pausing")
                    self.pause()
                }
            }
        }
        #endif
    }

    // -------------------------------------------------------------
    // WebKit Setup with YouTube Official IFrame API
    // -------------------------------------------------------------
    private func setupBackgroundWebView() {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
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

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          * { margin:0; padding:0; box-sizing:border-box; }
          html, body { width:100%; height:100%; background:#000000; overflow:hidden; }
          #player { width:100% !important; height:100% !important; }
        </style>
        <script>
          // Block background auto-pause: prevent YouTube from pausing when iOS locks screen
          try {
            Object.defineProperty(document, 'hidden', { get: function() { return false; }, configurable: true });
            Object.defineProperty(document, 'visibilityState', { get: function() { return 'visible'; }, configurable: true });
            Object.defineProperty(document, 'webkitVisibilityState', { get: function() { return 'visible'; }, configurable: true });
            document.hasFocus = function() { return true; };
            window.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
            document.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
          } catch(e) {}
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </head>
        <body>
        <div id="player"></div>
        <script>
        var player = null;
        var isReady = false;
        var pendingId = null;

        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player', {
            height: '100%',
            width: '100%',
            playerVars: {
              'autoplay': 1,
              'controls': 0,
              'disablekb': 1,
              'fs': 0,
              'modestbranding': 1,
              'playsinline': 1,
              'rel': 0
            },
            events: {
              'onReady': function(e) {
                isReady = true;
                try {
                  e.target.unMute();
                  e.target.setVolume(100);
                } catch(err) {}
                window.webkit.messageHandlers.audioBridge.postMessage({ type: 'READY' });
                if (pendingId) {
                  playTrack(pendingId);
                  pendingId = null;
                }
              },
              'onStateChange': function(e) {
                if (e.data === 1) { // Playing -> ensure unmuted
                  try {
                    e.target.unMute();
                    e.target.setVolume(100);
                  } catch(err) {}
                }
                window.webkit.messageHandlers.audioBridge.postMessage({ type: 'STATE', state: e.data });
              },
              'onError': function(e) {
                window.webkit.messageHandlers.audioBridge.postMessage({ type: 'ERROR', code: e.data });
              }
            }
          });

          setInterval(function() {
            if (isReady && player && typeof player.getCurrentTime === 'function') {
              try {
                var cur = player.getCurrentTime() || 0;
                var dur = player.getDuration() || 0;
                if (dur > 0) {
                  window.webkit.messageHandlers.audioBridge.postMessage({
                    type: 'PROGRESS',
                    current: cur,
                    duration: dur
                  });
                }
              } catch(e) {}
            }
          }, 350);
        }

        function playTrack(vid) {
          if (!isReady || !player || typeof player.loadVideoById !== 'function') {
            pendingId = vid;
            return;
          }
          try {
            player.unMute();
            player.setVolume(100);
            player.loadVideoById(vid);
            player.playVideo();
          } catch(err) {
            pendingId = vid;
          }
        }

        var isUserPaused = false;

        function playTrack(vid) {
          isUserPaused = false;
          if (!isReady || !player || typeof player.loadVideoById !== 'function') {
            pendingId = vid;
            return;
          }
          try {
            player.unMute();
            player.setVolume(100);
            player.loadVideoById(vid);
            player.playVideo();
          } catch(err) {
            pendingId = vid;
          }
        }

        function resumeTrack() {
          isUserPaused = false;
          if (player && typeof player.playVideo === 'function') {
            try {
              player.unMute();
              player.setVolume(100);
              player.playVideo();
            } catch(e) {}
          }
        }

        function pauseTrack() {
          isUserPaused = true;
          if (player && typeof player.pauseVideo === 'function') {
            try { player.pauseVideo(); } catch(e) {}
          }
        }

        function seekTrack(sec) {
          if (player && typeof player.seekTo === 'function') {
            try { player.seekTo(sec, true); } catch(e) {}
          }
        }

        // Lock screen keep-alive: prevent WebKit from suspending audio when display turns off
        document.addEventListener("visibilitychange", function() {
          if (!isUserPaused && player && typeof player.playVideo === 'function') {
            try { player.playVideo(); } catch(e) {}
          }
        });
        window.addEventListener("pagehide", function() {
          if (!isUserPaused && player && typeof player.playVideo === 'function') {
            try { player.playVideo(); } catch(e) {}
          }
        });
        </script>
        </body>
        </html>
        """
        wv.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch type {
            case "READY":
                self.isWebViewReady = true
                if let queued = self.queuedVideoId {
                    self.webView?.evaluateJavaScript("playTrack('\(queued)');")
                    self.queuedVideoId = nil
                }
            case "STATE":
                if let state = dict["state"] as? Int {
                    if state == 1 { // Playing
                        self.isPlaying = true
                        if let song = self.currentSong {
                            self.updateNowPlayingInfo(song: song)
                        }
                    } else if state == 2 { // Paused
                        self.isPlaying = false
                        if let song = self.currentSong {
                            self.updateNowPlayingInfo(song: song)
                        }
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
        pausedByInterruption = false
        isUserInitiatedPause = false
        configureAudioSession()
        keepAlivePlayer?.play()

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

        // Queue and play through YouTube Audio Engine with unMute guarantee
        queuedVideoId = song.id
        let js = "playTrack('\(song.id)');"
        webView?.evaluateJavaScript(js) { [weak self] (_, error) in
            if error != nil {
                self?.queuedVideoId = song.id
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

    private func playInternal() {
        configureAudioSession()
        keepAlivePlayer?.play()
        isUserInitiatedPause = false
        webView?.evaluateJavaScript("resumeTrack();")
        isPlaying = true
        if let song = currentSong {
            updateNowPlayingInfo(song: song)
        }
    }

    private func pauseInternal() {
        keepAlivePlayer?.pause()
        webView?.evaluateJavaScript("pauseTrack();")
        isPlaying = false
        if let song = currentSong {
            updateNowPlayingInfo(song: song)
        }
    }

    public func play() {
        pausedByInterruption = false
        playInternal()
    }

    public func pause() {
        isUserInitiatedPause = true
        pausedByInterruption = false
        pauseInternal()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    public func seek(to seconds: Double) {
        currentTime = seconds
        webView?.evaluateJavaScript("seekTrack(\(seconds));")
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
// WebKit Background View Representable
// -------------------------------------------------------------
public struct YouTubeBackgroundPlayerView: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))

        if let wv = AudioPlayerService.shared.webView {
            wv.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
            wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.addSubview(wv)
        }

        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}
