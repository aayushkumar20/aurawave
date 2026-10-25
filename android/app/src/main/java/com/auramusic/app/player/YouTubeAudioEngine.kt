package com.auramusic.app.player

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient

class BackgroundAudioWebView(context: Context) : WebView(context) {
    override fun onWindowVisibilityChanged(visibility: Int) {
        // Prevent Chromium from auto-pausing media when window is hidden or locked
        super.onWindowVisibilityChanged(View.VISIBLE)
    }

    override fun dispatchWindowVisibilityChanged(visibility: Int) {
        super.dispatchWindowVisibilityChanged(View.VISIBLE)
    }

    override fun onVisibilityChanged(changedView: View, visibility: Int) {
        super.onVisibilityChanged(changedView, View.VISIBLE)
    }

    override fun onScreenStateChanged(screenState: Int) {
        super.onScreenStateChanged(View.SCREEN_STATE_ON)
    }
}

class YouTubeAudioEngine(private val context: Context) {
    private var webView: BackgroundAudioWebView? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isReady = false
    private var pendingSongId: String? = null

    var onReadyCallback: (() -> Unit)? = null
    var onStateChangedCallback: ((Int) -> Unit)? = null
    var onProgressCallback: ((currentSec: Double, durationSec: Double) -> Unit)? = null
    var onErrorCallback: ((Int) -> Unit)? = null

    init {
        mainHandler.post {
            setupWebView()
        }
    }

    fun getPlayerView(): View? {
        if (webView == null) {
            setupWebView()
        }
        return webView
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        if (webView != null) return

        val wv = BackgroundAudioWebView(context.applicationContext)
        val s = wv.settings
        s.javaScriptEnabled = true
        s.mediaPlaybackRequiresUserGesture = false
        s.domStorageEnabled = true
        s.databaseEnabled = true
        s.loadWithOverviewMode = true
        s.useWideViewPort = true
        s.cacheMode = WebSettings.LOAD_DEFAULT
        s.userAgentString = "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"

        wv.addJavascriptInterface(AudioBridge(), "audioBridge")
        wv.webChromeClient = WebChromeClient()
        wv.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                Log.d("AuraPlayback", "YouTube WebView Page Finished: $url")
            }
        }

        val html = """
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
          // Block background auto-pause: prevent YouTube from pausing when screen turns off
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
                if (window.audioBridge) {
                  window.audioBridge.onReady();
                }
                if (pendingId) {
                  playTrack(pendingId);
                  pendingId = null;
                }
              },
              'onStateChange': function(e) {
                if (e.data === 1) { // Playing
                  try {
                    e.target.unMute();
                    e.target.setVolume(100);
                  } catch(err) {}
                }
                if (window.audioBridge) {
                  window.audioBridge.onStateChange(e.data);
                }
              },
              'onError': function(e) {
                if (window.audioBridge) {
                  window.audioBridge.onError(e.data);
                }
              }
            }
          });

          setInterval(function() {
            if (isReady && player && typeof player.getCurrentTime === 'function') {
              try {
                var cur = player.getCurrentTime() || 0;
                var dur = player.getDuration() || 0;
                if (dur > 0 && window.audioBridge) {
                  window.audioBridge.onProgress(cur, dur);
                }
              } catch(e) {}
            }
          }, 350);
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

        // Lock screen keep-alive: prevent background throttling from stopping playback
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

        // Intercept any unwanted pause event from OS/Chromium when screen is locked
        document.addEventListener("pause", function(e) {
          if (!isUserPaused && player && typeof player.playVideo === 'function') {
            try { player.playVideo(); } catch(err) {}
          }
        }, true);

        // Active Watchdog: Auto-resumes within 250ms if lock screen triggers unexpected pause
        setInterval(function() {
          if (!isUserPaused && isReady && player && typeof player.getPlayerState === 'function') {
            try {
              if (player.getPlayerState() === 2) {
                player.playVideo();
              }
            } catch(err) {}
          }
        }, 250);
        </script>
        </body>
        </html>
        """.trimIndent()

        wv.loadDataWithBaseURL("https://www.youtube-nocookie.com", html, "text/html", "UTF-8", null)
        wv.resumeTimers()
        this.webView = wv
    }

    fun playTrack(videoId: String) {
        mainHandler.post {
            Log.d("AuraPlayback", "playTrack requested for: $videoId (isReady=$isReady)")
            if (!isReady) {
                pendingSongId = videoId
            }
            webView?.evaluateJavascript("playTrack('$videoId');", null)
        }
    }

    fun resume() {
        mainHandler.post {
            webView?.evaluateJavascript("resumeTrack();", null)
        }
    }

    fun pause() {
        mainHandler.post {
            webView?.evaluateJavascript("pauseTrack();", null)
        }
    }

    fun seekTo(seconds: Double) {
        mainHandler.post {
            webView?.evaluateJavascript("seekTrack($seconds);", null)
        }
    }

    fun release() {
        mainHandler.post {
            webView?.destroy()
            webView = null
        }
    }

    inner class AudioBridge {
        @JavascriptInterface
        fun onReady() {
            mainHandler.post {
                Log.d("AuraPlayback", "Bridge onReady received")
                isReady = true
                onReadyCallback?.invoke()
                pendingSongId?.let {
                    playTrack(it)
                    pendingSongId = null
                }
            }
        }

        @JavascriptInterface
        fun onStateChange(state: Int) {
            mainHandler.post {
                Log.d("AuraPlayback", "Bridge onStateChange: $state")
                onStateChangedCallback?.invoke(state)
            }
        }

        @JavascriptInterface
        fun onProgress(currentSec: Double, durationSec: Double) {
            mainHandler.post {
                onProgressCallback?.invoke(currentSec, durationSec)
            }
        }

        @JavascriptInterface
        fun onError(code: Int) {
            mainHandler.post {
                Log.e("AuraPlayback", "Bridge onError: $code")
                onErrorCallback?.invoke(code)
            }
        }
    }
}
