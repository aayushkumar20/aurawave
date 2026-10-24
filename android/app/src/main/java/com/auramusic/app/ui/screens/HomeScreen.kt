package com.auramusic.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ElectricBolt
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.auramusic.app.data.models.Song
import com.auramusic.app.player.PlaybackManager
import com.auramusic.app.ui.components.SongItem
import com.auramusic.app.ui.theme.AuraAccent
import com.auramusic.app.ui.theme.AuraBackground
import com.auramusic.app.ui.theme.AuraPrimary
import com.auramusic.app.ui.theme.AuraSurface
import com.auramusic.app.ui.theme.AuraTextMuted
import com.auramusic.app.ui.theme.AuraTextPrimary
import com.auramusic.app.ui.theme.AuraTextSecondary

@Composable
fun HomeScreen(
    onNavigateToChat: () -> Unit
) {
    val currentSong by PlaybackManager.currentSong.collectAsState()
    val favorites by PlaybackManager.favorites.collectAsState()
    val trendingSongs by PlaybackManager.trendingSongs.collectAsState()
    val isLoading by PlaybackManager.isLoadingTrending.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(AuraBackground),
        contentPadding = PaddingValues(bottom = 120.dp)
    ) {
        // App Header
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 18.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "AURA MUSIC",
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Black,
                        color = AuraTextPrimary,
                        letterSpacing = 1.sp
                    )
                    Text(
                        text = "Live Stream • 100% Ad-Free",
                        fontSize = 12.sp,
                        color = AuraAccent,
                        fontWeight = FontWeight.Medium
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = { PlaybackManager.loadLiveTrending() },
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
                            tint = AuraAccent,
                            modifier = Modifier.size(20.dp)
                        )
                    }

                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(AuraPrimary.copy(alpha = 0.2f))
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.ElectricBolt,
                                contentDescription = null,
                                tint = AuraAccent,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "AD-BLOCK ON",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = AuraAccent
                            )
                        }
                    }
                }
            }
        }

        if (isLoading && trendingSongs.isEmpty()) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(280.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator(color = AuraAccent, modifier = Modifier.size(38.dp))
                        Spacer(modifier = Modifier.height(14.dp))
                        Text(
                            text = "Fetching live YouTube Music charts...",
                            color = AuraTextMuted,
                            fontSize = 13.sp
                        )
                    }
                }
            }
        } else {
            // Hero Spotlight Banner
            item {
                val featuredSong = trendingSongs.firstOrNull()
                if (featuredSong != null) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 20.dp)
                            .height(180.dp)
                            .clip(RoundedCornerShape(20.dp))
                            .clickable { PlaybackManager.playSong(featuredSong) }
                    ) {
                        AsyncImage(
                            model = featuredSong.thumbnailUrl,
                            contentDescription = featuredSong.title,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize()
                        )

                        // Gradient Overlay
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(
                                    Brush.verticalGradient(
                                        listOf(AuraSurface.copy(alpha = 0.2f), AuraBackground.copy(alpha = 0.95f))
                                    )
                                )
                        )

                        Column(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(18.dp),
                            verticalArrangement = Arrangement.Bottom
                        ) {
                            Text(
                                text = "REAL-TIME SPOTLIGHT",
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = AuraAccent,
                                letterSpacing = 1.sp
                            )
                            Text(
                                text = featuredSong.title,
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Bold,
                                color = AuraTextPrimary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = featuredSong.artist,
                                fontSize = 14.sp,
                                color = AuraTextSecondary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }

                        IconButton(
                            onClick = { PlaybackManager.playSong(featuredSong) },
                            modifier = Modifier
                                .align(Alignment.BottomEnd)
                                .padding(16.dp)
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(AuraPrimary)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = "Play",
                                tint = AuraTextPrimary,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(24.dp))
                }
            }

            // Quick Picks Horizontal Row
            item {
                Text(
                    text = "Live Top Picks",
                    color = AuraTextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                )

                LazyRow(
                    contentPadding = PaddingValues(horizontal = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    items(trendingSongs.take(10)) { song ->
                        Column(
                            modifier = Modifier
                                .width(130.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .clickable { PlaybackManager.playSong(song) }
                        ) {
                            AsyncImage(
                                model = song.thumbnailUrl,
                                contentDescription = song.title,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .size(130.dp)
                                    .clip(RoundedCornerShape(12.dp))
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = song.title,
                                color = AuraTextPrimary,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 13.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = song.artist,
                                color = AuraTextMuted,
                                fontSize = 11.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))
            }

            // Trending Tracks Section
            item {
                Text(
                    text = "Trending YouTube Music",
                    color = AuraTextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)
                )
            }

            items(trendingSongs.drop(1)) { song ->
                Box(modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp)) {
                    SongItem(
                        song = song,
                        isPlayingThisSong = currentSong?.id == song.id,
                        isFavorite = favorites.contains(song.id),
                        onClick = { PlaybackManager.playSong(song) },
                        onPlayNext = { PlaybackManager.playNext(song) },
                        onPlayLast = { PlaybackManager.playLast(song) },
                        onToggleFavorite = { PlaybackManager.toggleFavorite(song) },
                        onShareToChat = onNavigateToChat
                    )
                }
            }
        }
    }
}
