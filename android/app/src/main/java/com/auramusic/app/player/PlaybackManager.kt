package com.auramusic.app.player

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.auramusic.app.data.api.YouTubeMusicEngine
import com.auramusic.app.data.models.Playlist
import com.auramusic.app.data.models.RepeatMode
import com.auramusic.app.data.models.Song
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

object PlaybackManager {
    private var exoPlayer: ExoPlayer? = null
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private var progressJob: Job? = null

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
        if (exoPlayer != null) return

        exoPlayer = ExoPlayer.Builder(context).build().apply {
            addListener(object : Player.Listener {
                override fun onIsPlayingChanged(playing: Boolean) {
                    _isPlaying.value = playing
                    if (playing) {
                        startProgressUpdates()
                    } else {
                        stopProgressUpdates()
                    }
                }

                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_READY -> {
                            _durationMs.value = duration.coerceAtLeast(0L)
                        }
                        Player.STATE_ENDED -> {
                            handleTrackEnded()
                        }
                    }
                }
            })
        }

        // Fetch real-time live trending songs from YouTube Music
        loadLiveTrending()
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

    private fun startProgressUpdates() {
        progressJob?.cancel()
        progressJob = scope.launch {
            while (isActive) {
                exoPlayer?.let { player ->
                    _currentPositionMs.value = player.currentPosition.coerceAtLeast(0L)
                    _durationMs.value = player.duration.coerceAtLeast(0L)
                }
                delay(300)
            }
        }
    }

    private fun stopProgressUpdates() {
        progressJob?.cancel()
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
        loadAndPlay(song)
    }

    /**
     * User requirement: Play Next (inserts immediately after the active song in queue)
     */
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

    /**
     * User requirement: Play Last (appends to end of current queue)
     */
    fun playLast(song: Song) {
        val currentQueue = _queue.value.toMutableList()
        val existingIndex = currentQueue.indexOfFirst { it.id == song.id }
        if (existingIndex != -1) {
            currentQueue.removeAt(existingIndex)
        }
        currentQueue.add(song)
        _queue.value = currentQueue
    }

    fun togglePlayPause() {
        val player = exoPlayer ?: return
        if (player.isPlaying) {
            player.pause()
        } else {
            if (_currentSong.value == null && _queue.value.isNotEmpty()) {
                playSong(_queue.value[0])
            } else {
                player.play()
            }
        }
    }

    fun seekTo(positionMs: Long) {
        exoPlayer?.seekTo(positionMs)
        _currentPositionMs.value = positionMs
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
        _currentSong.value = nextSong
        loadAndPlay(nextSong)
    }

    fun skipPrevious() {
        val q = _queue.value
        if (q.isEmpty()) return
        val prevIdx = if (_currentIndex.value - 1 < 0) q.size - 1 else _currentIndex.value - 1
        _currentIndex.value = prevIdx
        val prevSong = q[prevIdx]
        _currentSong.value = prevSong
        loadAndPlay(prevSong)
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
                exoPlayer?.seekTo(0)
                exoPlayer?.play()
            }
            RepeatMode.ALL, RepeatMode.OFF -> {
                skipNext()
            }
        }
    }

    private fun loadAndPlay(song: Song) {
        scope.launch {
            val resolvedUrl = YouTubeMusicEngine.resolveStreamUrl(song)
            val mediaItem = MediaItem.fromUri(resolvedUrl)
            exoPlayer?.let { player ->
                player.setMediaItem(mediaItem)
                player.prepare()
                player.play()
            }
        }
    }
}
