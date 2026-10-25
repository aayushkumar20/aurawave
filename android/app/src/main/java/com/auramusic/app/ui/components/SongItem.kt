package com.auramusic.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.PlaylistAdd
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.auramusic.app.data.models.Song
import com.auramusic.app.ui.theme.AuraAccent
import com.auramusic.app.ui.theme.AuraCardBorder
import com.auramusic.app.ui.theme.AuraFavorite
import com.auramusic.app.ui.theme.AuraSurface
import com.auramusic.app.ui.theme.AuraSurfaceLight
import com.auramusic.app.ui.theme.AuraTextMuted
import com.auramusic.app.ui.theme.AuraTextPrimary
import com.auramusic.app.ui.theme.AuraTextSecondary

@Composable
fun SongItem(
    song: Song,
    isPlayingThisSong: Boolean = false,
    isFavorite: Boolean = false,
    onClick: () -> Unit,
    onPlayNext: () -> Unit,
    onPlayLast: () -> Unit,
    onToggleFavorite: () -> Unit,
    onShareToChat: () -> Unit,
    onAddToPlaylist: () -> Unit = {}
) {
    var showMenu by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isPlayingThisSong) AuraSurfaceLight else AuraSurface.copy(alpha = 0.5f))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Thumbnail with play indicator or visualizer
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            AsyncImage(
                model = song.thumbnailUrl,
                contentDescription = song.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.matchParentSize()
            )
            if (isPlayingThisSong) {
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .background(AuraSurface.copy(alpha = 0.6f)),
                    contentAlignment = Alignment.Center
                ) {
                    AudioVisualizer(isPlaying = true)
                }
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Title and Artist
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = song.title,
                color = if (isPlayingThisSong) AuraAccent else AuraTextPrimary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 15.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = "${song.artist} • ${song.durationText}",
                color = AuraTextSecondary,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        // Favorite Toggle
        IconButton(
            onClick = onToggleFavorite,
            modifier = Modifier.size(36.dp)
        ) {
            Icon(
                imageVector = if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                contentDescription = "Favorite",
                tint = if (isFavorite) AuraFavorite else AuraTextMuted,
                modifier = Modifier.size(20.dp)
            )
        }

        // More Options Menu (Play Next, Play Last, Share to Chat)
        Box {
            IconButton(
                onClick = { showMenu = true },
                modifier = Modifier.size(36.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.MoreVert,
                    contentDescription = "Options",
                    tint = AuraTextSecondary,
                    modifier = Modifier.size(20.dp)
                )
            }

            DropdownMenu(
                expanded = showMenu,
                onDismissRequest = { showMenu = false },
                modifier = Modifier.background(AuraSurfaceLight)
            ) {
                DropdownMenuItem(
                    text = { Text("Play Next", color = AuraTextPrimary) },
                    leadingIcon = {
                        Icon(Icons.Default.QueueMusic, contentDescription = null, tint = AuraAccent)
                    },
                    onClick = {
                        showMenu = false
                        onPlayNext()
                    }
                )
                DropdownMenuItem(
                    text = { Text("Play Last", color = AuraTextPrimary) },
                    leadingIcon = {
                        Icon(Icons.Default.PlaylistAdd, contentDescription = null, tint = AuraTextSecondary)
                    },
                    onClick = {
                        showMenu = false
                        onPlayLast()
                    }
                )
                DropdownMenuItem(
                    text = { Text("Add to Group Playlist 🎶", color = AuraAccent) },
                    leadingIcon = {
                        Icon(Icons.Default.PlaylistAdd, contentDescription = null, tint = AuraAccent)
                    },
                    onClick = {
                        showMenu = false
                        com.auramusic.app.data.repository.ChatManager.addSongToGroupPlaylist(song)
                    }
                )
                DropdownMenuItem(
                    text = { Text("Share to Chat", color = AuraTextPrimary) },
                    leadingIcon = {
                        Icon(Icons.Default.Chat, contentDescription = null, tint = AuraAccent)
                    },
                    onClick = {
                        showMenu = false
                        onShareToChat()
                    }
                )
                DropdownMenuItem(
                    text = { Text("Add to Playlist", color = AuraTextPrimary) },
                    leadingIcon = {
                        Icon(Icons.Default.PlaylistAdd, contentDescription = null, tint = AuraTextSecondary)
                    },
                    onClick = {
                        showMenu = false
                        onAddToPlaylist()
                    }
                )
            }
        }
    }
}
