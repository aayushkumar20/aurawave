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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.NorthWest
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.auramusic.app.data.api.YouTubeMusicEngine
import com.auramusic.app.data.models.Song
import com.auramusic.app.player.PlaybackManager
import com.auramusic.app.ui.components.SongItem
import com.auramusic.app.ui.theme.AuraAccent
import com.auramusic.app.ui.theme.AuraBackground
import com.auramusic.app.ui.theme.AuraPrimary
import com.auramusic.app.ui.theme.AuraSurface
import com.auramusic.app.ui.theme.AuraSurfaceLight
import com.auramusic.app.ui.theme.AuraTextMuted
import com.auramusic.app.ui.theme.AuraTextPrimary
import com.auramusic.app.ui.theme.AuraTextSecondary
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun SearchScreen(
    onNavigateToChat: () -> Unit
) {
    var query by remember { mutableStateOf("") }
    var searchResults by remember { mutableStateOf<List<Song>>(emptyList()) }
    var suggestions by remember { mutableStateOf<List<String>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var selectedFilter by remember { mutableStateOf("All") }

    val currentSong by PlaybackManager.currentSong.collectAsState()
    val favorites by PlaybackManager.favorites.collectAsState()
    val trendingSongs by PlaybackManager.trendingSongs.collectAsState()
    val scope = rememberCoroutineScope()
    var searchJob by remember { mutableStateOf<Job?>(null) }
    var suggestJob by remember { mutableStateOf<Job?>(null) }

    val filters = listOf("All", "Top Hits", "Hip-Hop", "Electronic", "Chill", "Rock")

    fun triggerSearch(searchQuery: String) {
        searchJob?.cancel()
        suggestJob?.cancel()
        suggestions = emptyList()

        if (searchQuery.isBlank()) {
            searchResults = emptyList()
            isLoading = false
            return
        }

        isLoading = true
        searchJob = scope.launch {
            delay(300) // debounce
            val results = YouTubeMusicEngine.searchSongs(searchQuery)
            searchResults = results
            isLoading = false
        }
    }

    fun triggerSuggest(inputText: String) {
        suggestJob?.cancel()
        if (inputText.isBlank()) {
            suggestions = emptyList()
            return
        }

        suggestJob = scope.launch {
            delay(150)
            val list = YouTubeMusicEngine.getSearchSuggestions(inputText)
            suggestions = list
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AuraBackground)
    ) {
        // Search Header & Input
        Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp)) {
            Text(
                text = "Live Search & Suggest",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = AuraTextPrimary
            )
            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = query,
                onValueChange = {
                    query = it
                    triggerSuggest(it)
                    triggerSearch(it)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp)),
                placeholder = { Text("Search any song, artist, album live...", color = AuraTextMuted) },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Search",
                        tint = AuraAccent
                    )
                },
                trailingIcon = {
                    if (query.isNotEmpty()) {
                        IconButton(onClick = {
                            query = ""
                            suggestions = emptyList()
                            searchResults = emptyList()
                        }) {
                            Icon(Icons.Default.Clear, contentDescription = "Clear", tint = AuraTextMuted)
                        }
                    }
                },
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = AuraAccent,
                    unfocusedBorderColor = AuraSurfaceLight,
                    focusedContainerColor = AuraSurface,
                    unfocusedContainerColor = AuraSurface,
                    focusedTextColor = AuraTextPrimary,
                    unfocusedTextColor = AuraTextPrimary
                )
            )

            // Real-time suggestions popup chips
            if (suggestions.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(suggestions) { item ->
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(16.dp))
                                .background(AuraSurfaceLight)
                                .clickable {
                                    query = item
                                    suggestions = emptyList()
                                    triggerSearch(item)
                                }
                                .padding(horizontal = 10.dp, vertical = 5.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.TrendingUp,
                                contentDescription = null,
                                tint = AuraAccent,
                                modifier = Modifier.size(12.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = item,
                                color = AuraTextPrimary,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Filter Chips
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(filters) { filter ->
                    val isSelected = selectedFilter == filter
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(if (isSelected) AuraPrimary else AuraSurface)
                            .clickable {
                                selectedFilter = filter
                                if (filter != "All") {
                                    query = filter
                                    triggerSearch(filter)
                                }
                            }
                            .padding(horizontal = 14.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = filter,
                            color = if (isSelected) AuraTextPrimary else AuraTextSecondary,
                            fontSize = 12.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                }
            }
        }

        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 40.dp),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = AuraAccent, modifier = Modifier.size(36.dp))
            }
        } else {
            val listToDisplay = if (searchResults.isNotEmpty()) searchResults else trendingSongs

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                if (searchResults.isEmpty() && trendingSongs.isNotEmpty()) {
                    item {
                        Text(
                            text = "Trending Searches & Tracks",
                            color = AuraTextMuted,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(bottom = 6.dp)
                        )
                    }
                }

                items(listToDisplay) { song ->
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
