package com.auramusic.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.RepeatOne
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.auramusic.app.data.models.RepeatMode
import com.auramusic.app.data.models.Song
import com.auramusic.app.player.PlaybackManager
import com.auramusic.app.ui.components.AudioVisualizer
import com.auramusic.app.ui.components.SongItem
import com.auramusic.app.ui.theme.AuraAccent
import com.auramusic.app.ui.theme.AuraBackground
import com.auramusic.app.ui.theme.AuraFavorite
import com.auramusic.app.ui.theme.AuraPink
import com.auramusic.app.ui.theme.AuraPrimary
import com.auramusic.app.ui.theme.AuraSurface
import com.auramusic.app.ui.theme.AuraSurfaceLight
import com.auramusic.app.ui.theme.AuraTextMuted
import com.auramusic.app.ui.theme.AuraTextPrimary
import com.auramusic.app.ui.theme.AuraTextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NowPlayingSheet(
    onDismiss: () -> Unit,
    onNavigateToChat: () -> Unit
) {
    val currentSong by PlaybackManager.currentSong.collectAsState()
    val isPlaying by PlaybackManager.isPlaying.collectAsState()
    val progressMs by PlaybackManager.currentPositionMs.collectAsState()
    val durationMs by PlaybackManager.durationMs.collectAsState()
    val isShuffle by PlaybackManager.isShuffleEnabled.collectAsState()
    val repeatMode by PlaybackManager.repeatMode.collectAsState()
    val queue by PlaybackManager.queue.collectAsState()
    val currentIndex by PlaybackManager.currentIndex.collectAsState()
    val favorites by PlaybackManager.favorites.collectAsState()

    var showQueueList by remember { mutableStateOf(false) }

    androidx.compose.runtime.LaunchedEffect(currentSong) {
        if (currentSong == null) {
            onDismiss()
        }
    }

    if (currentSong == null) return

    val song = currentSong!!
    val isFav = favorites.contains(song.id)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(AuraSurfaceLight, AuraBackground, AuraBackground)
                )
            )
            .padding(horizontal = 24.dp)
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // Top bar
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onDismiss) {
                Icon(
                    imageVector = Icons.Default.KeyboardArrowDown,
                    contentDescription = "Collapse",
                    tint = AuraTextPrimary,
                    modifier = Modifier.size(32.dp)
                )
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "PLAYING FROM YOUTUBE MUSIC",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = AuraTextMuted,
                    letterSpacing = 1.sp
                )
                Text(
                    text = if (showQueueList) "Up Next Queue" else song.album,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AuraAccent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            IconButton(onClick = { showQueueList = !showQueueList }) {
                Icon(
                    imageVector = Icons.Default.QueueMusic,
                    contentDescription = "Queue",
                    tint = if (showQueueList) AuraAccent else AuraTextSecondary,
                    modifier = Modifier.size(26.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        if (showQueueList) {
            // Queue view
            Text(
                text = "Playing Next (${queue.size} songs)",
                color = AuraTextPrimary,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                modifier = Modifier.padding(bottom = 12.dp)
            )

            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                itemsIndexed(queue) { idx, item ->
                    SongItem(
                        song = item,
                        isPlayingThisSong = idx == currentIndex,
                        isFavorite = favorites.contains(item.id),
                        onClick = { PlaybackManager.playSong(item) },
                        onPlayNext = { PlaybackManager.playNext(item) },
                        onPlayLast = { PlaybackManager.playLast(item) },
                        onToggleFavorite = { PlaybackManager.toggleFavorite(item) },
                        onShareToChat = {
                            onDismiss()
                            onNavigateToChat()
                        }
                    )
                }
            }
        } else {
            // Artwork Box
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1f)
                    .clip(RoundedCornerShape(24.dp))
                    .shadow(elevation = 20.dp, shape = RoundedCornerShape(24.dp), ambientColor = AuraPrimary, spotColor = AuraAccent)
            ) {
                AsyncImage(
                    model = song.thumbnailUrl,
                    contentDescription = song.title,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )
            }

            Spacer(modifier = Modifier.height(28.dp))

            // Song Info & Fav
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = song.title,
                        color = AuraTextPrimary,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = song.artist,
                        color = AuraTextSecondary,
                        fontSize = 16.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onNavigateToChat) {
                        Icon(
                            imageVector = Icons.Default.Chat,
                            contentDescription = "Share to Chat",
                            tint = AuraAccent,
                            modifier = Modifier.size(24.dp)
                        )
                    }

                    IconButton(onClick = { PlaybackManager.toggleFavorite(song) }) {
                        Icon(
                            imageVector = if (isFav) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                            contentDescription = "Favorite",
                            tint = if (isFav) AuraFavorite else AuraTextMuted,
                            modifier = Modifier.size(28.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(18.dp))

            // Audio Visualizer
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center
            ) {
                AudioVisualizer(
                    isPlaying = isPlaying,
                    barCount = 12,
                    height = 20.dp,
                    barWidth = 4.dp
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Progress Slider
            var isUserSeeking by remember { mutableStateOf(false) }
            var seekPosition by remember { mutableStateOf(0f) }

            val maxProgress = if (durationMs > 0) durationMs.toFloat() else 1f
            val currentProg = if (isUserSeeking) seekPosition else progressMs.toFloat().coerceIn(0f, maxProgress)

            Slider(
                value = currentProg,
                onValueChange = {
                    isUserSeeking = true
                    seekPosition = it
                },
                onValueChangeFinished = {
                    isUserSeeking = false
                    PlaybackManager.seekTo(seekPosition.toLong())
                },
                valueRange = 0f..maxProgress,
                colors = SliderDefaults.colors(
                    thumbColor = AuraAccent,
                    activeTrackColor = AuraPrimary,
                    inactiveTrackColor = AuraSurfaceLight
                ),
                modifier = Modifier.fillMaxWidth()
            )

            // Timers
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = formatMs(progressMs),
                    color = AuraTextMuted,
                    fontSize = 12.sp
                )
                Text(
                    text = formatMs(durationMs),
                    color = AuraTextMuted,
                    fontSize = 12.sp
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Main Controls
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Shuffle
                IconButton(onClick = { PlaybackManager.toggleShuffle() }) {
                    Icon(
                        imageVector = Icons.Default.Shuffle,
                        contentDescription = "Shuffle",
                        tint = if (isShuffle) AuraAccent else AuraTextMuted
                    )
                }

                // Previous
                IconButton(
                    onClick = { PlaybackManager.skipPrevious() },
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.SkipPrevious,
                        contentDescription = "Previous",
                        tint = AuraTextPrimary,
                        modifier = Modifier.size(36.dp)
                    )
                }

                // Play / Pause (Glowing Center Button)
                Box(
                    modifier = Modifier
                        .size(68.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(listOf(AuraPrimary, AuraAccent))
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    IconButton(
                        onClick = { PlaybackManager.togglePlayPause() },
                        modifier = Modifier.fillMaxSize()
                    ) {
                        Icon(
                            imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = if (isPlaying) "Pause" else "Play",
                            tint = AuraTextPrimary,
                            modifier = Modifier.size(38.dp)
                        )
                    }
                }

                // Next
                IconButton(
                    onClick = { PlaybackManager.skipNext() },
                    modifier = Modifier.size(48.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.SkipNext,
                        contentDescription = "Next",
                        tint = AuraTextPrimary,
                        modifier = Modifier.size(36.dp)
                    )
                }

                // Repeat Mode
                IconButton(onClick = { PlaybackManager.cycleRepeatMode() }) {
                    Icon(
                        imageVector = if (repeatMode == RepeatMode.ONE) Icons.Default.RepeatOne else Icons.Default.Repeat,
                        contentDescription = "Repeat",
                        tint = if (repeatMode != RepeatMode.OFF) AuraAccent else AuraTextMuted
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

private fun formatMs(ms: Long): String {
    val totalSeconds = (ms / 1000).coerceAtLeast(0)
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return String.format("%d:%02d", minutes, seconds)
}
