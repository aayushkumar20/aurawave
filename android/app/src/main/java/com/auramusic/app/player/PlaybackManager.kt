package com.auramusic.app.player

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import android.view.View
import androidx.core.content.ContextCompat
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import com.auramusic.app.data.api.YouTubeMusicEngine
import com.auramusic.app.data.models.Playlist
import com.auramusic.app.data.models.RepeatMode
import com.auramusic.app.data.models.Song
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

object PlaybackManager {
    private var appContext: Context? = null
    private var youTubeAudioEngine: YouTubeAudioEngine? = null
    private var exoPlayer: ExoPlayer? = null
    private var mediaSession: MediaSession? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var isUserInitiatedPause = false

    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    private var pausedByTransientFocusLoss = false
    private var isNoisyReceiverRegistered = false

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                Log.d("AuraPlayback", "ACTION_AUDIO_BECOMING_NOISY: Audio output changed -> pausing")
                pause()
            }
        }
    }

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        Log.d("AuraPlayback", "onAudioFocusChange: $focusChange")
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                // Permanent loss: another audio app took over (e.g. user played music in Spotify)
                Log.d("AuraPlayback", "AUDIOFOCUS_LOSS: Permanent focus loss -> pausing")
                pausedByTransientFocusLoss = false
                hasAudioFocus = false
                pauseInternal()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                // Transient loss: user opened video/status in Instagram, WhatsApp, TikTok, phone call
                Log.d("AuraPlayback", "AUDIOFOCUS_LOSS_TRANSIENT: External video/sound started -> pausing immediately")
                if (_isPlaying.value) {
                    pausedByTransientFocusLoss = true
                    pauseInternal()
                }
                hasAudioFocus = false
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                // Focus regained: external video/status ended, resume playback automatically
                Log.d("AuraPlayback", "AUDIOFOCUS_GAIN: Regained focus (wasTransientPaused=$pausedByTransientFocusLoss)")
                hasAudioFocus = true
                if (pausedByTransientFocusLoss) {
                    pausedByTransientFocusLoss = false
                    playInternal()
                }
            }
        }
    }

    private fun requestAudioFocus(): Boolean {
        val am = audioManager ?: return false
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (audioFocusRequest == null) {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()

                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(audioAttributes)
                    .setAcceptsDelayedFocusGain(true)
                    .setOnAudioFocusChangeListener(audioFocusChangeListener)
                    .build()
            }
            am.requestAudioFocus(audioFocusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }

        hasAudioFocus = (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
        Log.d("AuraPlayback", "requestAudioFocus: result=$result (granted=$hasAudioFocus)")
        return hasAudioFocus
    }

    private fun abandonAudioFocus() {
        try {
            val am = audioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(audioFocusChangeListener)
            }
        } catch (e: Exception) {
            Log.e("AuraPlayback", "abandonAudioFocus failed: $e")
        } finally {
            hasAudioFocus = false
        }
    }

    private val scope = CoroutineScope(Dispatchers.Main + Job())

    private val _currentSong = MutableStateFlow<Song?>(null)
    val currentSong: StateFlow<Song?> = _currentSong.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _currentPositionMs = MutableStateFlow(0L)
    val currentPositionMs: StateFlow<Long> = _currentPositionMs.asStateFlow()

    private val _durationMs = MutableStateFlow(0L)
    val durationMs: StateFlow<Long> = _durationMs.asStateFlow()

    private val _queue = MutableStateFlow<List<Song>>(emptyList())
    val queue: StateFlow<List<Song>> = _queue.asStateFlow()

    private val _currentIndex = MutableStateFlow(0)
    val currentIndex: StateFlow<Int> = _currentIndex.asStateFlow()

    private val _isShuffleEnabled = MutableStateFlow(false)
    val isShuffleEnabled: StateFlow<Boolean> = _isShuffleEnabled.asStateFlow()

    private val _repeatMode = MutableStateFlow(RepeatMode.OFF)
    val repeatMode: StateFlow<RepeatMode> = _repeatMode.asStateFlow()

    private val _favorites = MutableStateFlow<Set<String>>(emptySet())
    val favorites: StateFlow<Set<String>> = _favorites.asStateFlow()

    private val _playlists = MutableStateFlow<List<Playlist>>(emptyList())
    val playlists: StateFlow<List<Playlist>> = _playlists.asStateFlow()

    private val _trendingSongs = MutableStateFlow<List<Song>>(emptyList())
    val trendingSongs: StateFlow<List<Song>> = _trendingSongs.asStateFlow()

    private val _isLoadingTrending = MutableStateFlow(true)
    val isLoadingTrending: StateFlow<Boolean> = _isLoadingTrending.asStateFlow()

    fun initialize(context: Context) {
        if (appContext != null) return
        val app = context.applicationContext
        appContext = app

        audioManager = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Register noisy audio receiver (pauses when headphones/Bluetooth disconnected)
        if (!isNoisyReceiverRegistered) {
            try {
                val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    app.registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    app.registerReceiver(noisyReceiver, filter)
                }
                isNoisyReceiverRegistered = true
            } catch (e: Exception) {
                Log.e("AuraPlayback", "Failed to register noisy receiver: $e")
            }
        }

        try {
            val powerManager = app.getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AuraMusic:PlaybackWakeLock")?.apply {
                setReferenceCounted(false)
            }
        } catch (e: Exception) {
            Log.e("AuraPlayback", "WakeLock init failed: $e")
        }

        // 1. Initialize High-Reliability YouTube Audio Engine (Matches iOS WebKit Engine)
        val engine = YouTubeAudioEngine(app)
        engine.onStateChangedCallback = { state ->
            when (state) {
                1 -> {
                    _isPlaying.value = true
                    startServiceAndAcquireWakeLock()
                }
                2 -> {
                    _isPlaying.value = false
                    releaseWakeLock()
                }
                0 -> {
                    if (_currentPositionMs.value > 3000L) {
                        handleTrackEnded()
                    }
                }
            }
        }
        engine.onProgressCallback = { curSec, durSec ->
            _currentPositionMs.value = (curSec * 1000.0).toLong()
            if (durSec > 0) {
                _durationMs.value = (durSec * 1000.0).toLong()
            }
        }
        engine.onErrorCallback = { _ ->
            // Try fallback
        }
        youTubeAudioEngine = engine

        // 2. Initialize Media3 ExoPlayer for system integration, hardware codecs & MediaSession
        try {
            val audioAttr = androidx.media3.common.AudioAttributes.Builder()
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .setUsage(C.USAGE_MEDIA)
                .build()

            exoPlayer = ExoPlayer.Builder(app).build().apply {
                setAudioAttributes(audioAttr, true)
                setHandleAudioBecomingNoisy(true)
                addListener(object : Player.Listener {
                    override fun onIsPlayingChanged(playing: Boolean) {
                        // Synced when playing via ExoPlayer
                    }

                    override fun onPlaybackStateChanged(playbackState: Int) {
                        if (playbackState == Player.STATE_ENDED) {
                            handleTrackEnded()
                        }
                    }
                })
            }
            mediaSession = MediaSession.Builder(app, exoPlayer!!).build()
        } catch (_: Exception) {}

        // Fetch live trending songs from YouTube Music
        loadLiveTrending()
    }

    fun getOrCreatePlayerView(context: Context): View {
        if (youTubeAudioEngine == null) {
            initialize(context)
        }
        return youTubeAudioEngine?.getPlayerView() ?: View(context)
    }

    fun getMediaSession(): MediaSession? = mediaSession

    private fun startServiceAndAcquireWakeLock() {
        try {
            appContext?.let { ctx ->
                val intent = Intent(ctx, PlaybackService::class.java)
                ContextCompat.startForegroundService(ctx, intent)
            }
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(3600_000L) // 1-hour safe wake lock for screen off
            }
        } catch (e: Exception) {
            Log.e("AuraPlayback", "startServiceAndAcquireWakeLock failed: $e")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    fun loadLiveTrending() {
        scope.launch {
            _isLoadingTrending.value = true
            val songs = YouTubeMusicEngine.fetchTrendingTracks()
            _trendingSongs.value = songs
            if (_queue.value.isEmpty() && songs.isNotEmpty()) {
                _queue.value = songs
                _currentSong.value = songs[0]
            }
            _isLoadingTrending.value = false
        }
    }

    fun playSong(song: Song) {
        val currentQueue = _queue.value.toMutableList()
        val index = currentQueue.indexOfFirst { it.id == song.id }
        if (index != -1) {
            _currentIndex.value = index
        } else {
            currentQueue.add(0, song)
            _queue.value = currentQueue
            _currentIndex.value = 0
        }

        _currentSong.value = song
        _currentPositionMs.value = 0L
        _durationMs.value = if (song.durationMs > 0) song.durationMs else 210_000L
        isUserInitiatedPause = false
        pausedByTransientFocusLoss = false

        if (requestAudioFocus()) {
            _isPlaying.value = true
            startServiceAndAcquireWakeLock()
            // Play via YouTube Audio Engine (100% complete full song, identical to iOS)
            youTubeAudioEngine?.playTrack(song.id)
        }
    }

    private fun playInternal() {
        if (!requestAudioFocus()) {
            Log.w("AuraPlayback", "playInternal: Audio focus request failed or delayed")
            return
        }
        startServiceAndAcquireWakeLock()
        youTubeAudioEngine?.resume()
        _isPlaying.value = true
    }

    private fun pauseInternal() {
        releaseWakeLock()
        youTubeAudioEngine?.pause()
        _isPlaying.value = false
    }

    fun play() {
        isUserInitiatedPause = false
        pausedByTransientFocusLoss = false
        playInternal()
    }

    fun pause() {
        isUserInitiatedPause = true
        pausedByTransientFocusLoss = false
        abandonAudioFocus()
        pauseInternal()
    }

    fun togglePlayPause() {
        if (_isPlaying.value) {
            pause()
        } else {
            if (_currentSong.value == null && _queue.value.isNotEmpty()) {
                playSong(_queue.value[0])
            } else {
                play()
            }
        }
    }

    fun seekTo(positionMs: Long) {
        _currentPositionMs.value = positionMs
        val seconds = positionMs / 1000.0
        youTubeAudioEngine?.seekTo(seconds)
    }

    fun skipNext() {
        val q = _queue.value
        if (q.isEmpty()) return
        val nextIdx = if (_isShuffleEnabled.value) {
            q.indices.random()
        } else {
            (_currentIndex.value + 1) % q.size
        }
        _currentIndex.value = nextIdx
        val nextSong = q[nextIdx]
        playSong(nextSong)
    }

    fun skipPrevious() {
        val q = _queue.value
        if (q.isEmpty()) return
        val prevIdx = if (_currentIndex.value - 1 < 0) q.size - 1 else _currentIndex.value - 1
        _currentIndex.value = prevIdx
        val prevSong = q[prevIdx]
        playSong(prevSong)
    }

    fun playNext(song: Song) {
        val currentQueue = _queue.value.toMutableList()
        val existingIndex = currentQueue.indexOfFirst { it.id == song.id }
        if (existingIndex != -1) {
            currentQueue.removeAt(existingIndex)
        }

        val insertIndex = (_currentIndex.value + 1).coerceAtMost(currentQueue.size)
        currentQueue.add(insertIndex, song)
        _queue.value = currentQueue
    }

    fun playLast(song: Song) {
        val currentQueue = _queue.value.toMutableList()
        val existingIndex = currentQueue.indexOfFirst { it.id == song.id }
        if (existingIndex != -1) {
            currentQueue.removeAt(existingIndex)
        }
        currentQueue.add(song)
        _queue.value = currentQueue
    }

    fun toggleShuffle() {
        _isShuffleEnabled.value = !_isShuffleEnabled.value
    }

    fun cycleRepeatMode() {
        _repeatMode.value = when (_repeatMode.value) {
            RepeatMode.OFF -> RepeatMode.ALL
            RepeatMode.ALL -> RepeatMode.ONE
            RepeatMode.ONE -> RepeatMode.OFF
        }
    }

    fun toggleFavorite(song: Song) {
        val currentFavs = _favorites.value.toMutableSet()
        if (currentFavs.contains(song.id)) {
            currentFavs.remove(song.id)
        } else {
            currentFavs.add(song.id)
        }
        _favorites.value = currentFavs
    }

    fun isFavorite(songId: String): Boolean {
        return _favorites.value.contains(songId)
    }

    fun createPlaylist(name: String, description: String = "") {
        val cover = _currentSong.value?.thumbnailUrl ?: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"
        val newPl = Playlist(
            id = "pl_${System.currentTimeMillis()}",
            name = name,
            description = description,
            coverUrl = cover,
            songs = emptyList()
        )
        _playlists.value = _playlists.value + newPl
    }

    fun addSongToPlaylist(playlistId: String, song: Song) {
        _playlists.value = _playlists.value.map { pl ->
            if (pl.id == playlistId) {
                if (pl.songs.none { it.id == song.id }) {
                    pl.copy(songs = pl.songs + song)
                } else pl
            } else pl
        }
    }

    private fun handleTrackEnded() {
        when (_repeatMode.value) {
            RepeatMode.ONE -> {
                seekTo(0)
                play()
            }
            RepeatMode.ALL -> {
                skipNext()
            }
            RepeatMode.OFF -> {
                val q = _queue.value
                if (_currentIndex.value < q.size - 1) {
                    skipNext()
                } else {
                    abandonAudioFocus()
                    pauseInternal()
                }
            }
        }
    }
}
