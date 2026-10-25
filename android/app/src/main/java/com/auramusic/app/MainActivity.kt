package com.auramusic.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.auramusic.app.player.PlaybackManager
import com.auramusic.app.ui.components.PlayerBar
import com.auramusic.app.ui.screens.ChatScreen
import com.auramusic.app.ui.screens.HomeScreen
import com.auramusic.app.ui.screens.LibraryScreen
import com.auramusic.app.ui.screens.NowPlayingSheet
import com.auramusic.app.ui.screens.SearchScreen
import com.auramusic.app.ui.theme.AuraAccent
import com.auramusic.app.ui.theme.AuraBackground
import com.auramusic.app.ui.theme.AuraMusicTheme
import com.auramusic.app.ui.theme.AuraPrimary
import com.auramusic.app.ui.theme.AuraSurface
import com.auramusic.app.ui.theme.AuraTextMuted
import kotlinx.coroutines.launch

enum class NavTab {
    HOME, SEARCH, LIBRARY, CHAT
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PlaybackManager.initialize(applicationContext)

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }

        setContent {
            AuraMusicTheme {
                AuraAppRoot()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuraAppRoot() {
    var currentTab by remember { mutableStateOf(NavTab.HOME) }
    var showNowPlaying by remember { mutableStateOf(false) }

    val currentSong by PlaybackManager.currentSong.collectAsState()
    val isPlaying by PlaybackManager.isPlaying.collectAsState()

    val scope = rememberCoroutineScope()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    fun dismissSheet() {
        scope.launch {
            try {
                sheetState.hide()
            } catch (_: Exception) {}
            showNowPlaying = false
        }
    }

    Scaffold(
        bottomBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AuraBackground)
            ) {
                // Persistent Floating Mini Player Bar docked right above NavigationBar
                if (currentSong != null) {
                    PlayerBar(
                        currentSong = currentSong,
                        isPlaying = isPlaying,
                        onTogglePlay = { PlaybackManager.togglePlayPause() },
                        onSkipNext = { PlaybackManager.skipNext() },
                        onClickBar = { showNowPlaying = true },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 4.dp)
                    )
                }

                NavigationBar(
                    containerColor = AuraSurface,
                    tonalElevation = 8.dp
                ) {
                    NavigationBarItem(
                        selected = currentTab == NavTab.HOME,
                        onClick = { currentTab = NavTab.HOME },
                        icon = { Icon(Icons.Default.Home, contentDescription = "Home") },
                        label = { Text("Home") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = AuraAccent,
                            selectedTextColor = AuraAccent,
                            unselectedIconColor = AuraTextMuted,
                            unselectedTextColor = AuraTextMuted,
                            indicatorColor = AuraPrimary.copy(alpha = 0.2f)
                        )
                    )

                    NavigationBarItem(
                        selected = currentTab == NavTab.SEARCH,
                        onClick = { currentTab = NavTab.SEARCH },
                        icon = { Icon(Icons.Default.Search, contentDescription = "Search") },
                        label = { Text("Search") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = AuraAccent,
                            selectedTextColor = AuraAccent,
                            unselectedIconColor = AuraTextMuted,
                            unselectedTextColor = AuraTextMuted,
                            indicatorColor = AuraPrimary.copy(alpha = 0.2f)
                        )
                    )

                    NavigationBarItem(
                        selected = currentTab == NavTab.LIBRARY,
                        onClick = { currentTab = NavTab.LIBRARY },
                        icon = { Icon(Icons.Default.LibraryMusic, contentDescription = "Library") },
                        label = { Text("Library") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = AuraAccent,
                            selectedTextColor = AuraAccent,
                            unselectedIconColor = AuraTextMuted,
                            unselectedTextColor = AuraTextMuted,
                            indicatorColor = AuraPrimary.copy(alpha = 0.2f)
                        )
                    )

                    NavigationBarItem(
                        selected = currentTab == NavTab.CHAT,
                        onClick = { currentTab = NavTab.CHAT },
                        icon = { Icon(Icons.Default.ChatBubble, contentDescription = "Chat") },
                        label = { Text("Chat") },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = AuraAccent,
                            selectedTextColor = AuraAccent,
                            unselectedIconColor = AuraTextMuted,
                            unselectedTextColor = AuraTextMuted,
                            indicatorColor = AuraPrimary.copy(alpha = 0.2f)
                        )
                    )
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Attached background audio player view (320x240 standard embed size so HTML5 adapters initialize cleanly)
            AndroidView(
                factory = { ctx ->
                    PlaybackManager.getOrCreatePlayerView(ctx)
                },
                modifier = Modifier
                    .size(320.dp, 240.dp)
                    .align(Alignment.Center)
            )

            // Deep solid canvas completely covering background player while forwarding all UI touches
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(AuraBackground)
            ) {
                when (currentTab) {
                    NavTab.HOME -> HomeScreen(onNavigateToChat = { currentTab = NavTab.CHAT })
                    NavTab.SEARCH -> SearchScreen(onNavigateToChat = { currentTab = NavTab.CHAT })
                    NavTab.LIBRARY -> LibraryScreen()
                    NavTab.CHAT -> ChatScreen()
                }
            }
        }

        // Full Screen Now Playing Bottom Sheet
        if (showNowPlaying && currentSong != null) {
            ModalBottomSheet(
                onDismissRequest = { dismissSheet() },
                sheetState = sheetState,
                containerColor = AuraBackground,
                dragHandle = null
            ) {
                NowPlayingSheet(
                    onDismiss = { dismissSheet() },
                    onNavigateToChat = {
                        dismissSheet()
                        currentTab = NavTab.CHAT
                    }
                )
            }
        }
    }
}
