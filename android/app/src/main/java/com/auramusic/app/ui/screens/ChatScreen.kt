package com.auramusic.app.ui.screens

import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.EmojiEmotions
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.PlaylistAdd
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.auramusic.app.data.models.ChatMessage
import com.auramusic.app.data.models.GroupPlaylistItem
import com.auramusic.app.data.repository.ChatManager
import com.auramusic.app.player.PlaybackManager
import com.auramusic.app.ui.theme.AuraAccent
import com.auramusic.app.ui.theme.AuraBackground
import com.auramusic.app.ui.theme.AuraCardBorder
import com.auramusic.app.ui.theme.AuraPrimary
import com.auramusic.app.ui.theme.AuraSuccess
import com.auramusic.app.ui.theme.AuraSurface
import com.auramusic.app.ui.theme.AuraSurfaceLight
import com.auramusic.app.ui.theme.AuraTextMuted
import com.auramusic.app.ui.theme.AuraTextPrimary
import com.auramusic.app.ui.theme.AuraTextSecondary

@Composable
fun ChatScreen() {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    val profile by ChatManager.currentProfile.collectAsState()
    val currentRoom by ChatManager.currentRoom.collectAsState()
    val availableRooms by ChatManager.availableRooms.collectAsState()
    val messages by ChatManager.messages.collectAsState()
    val groupPlaylist by ChatManager.groupPlaylist.collectAsState()
    val currentSong by PlaybackManager.currentSong.collectAsState()

    var showGroupDrawer by remember { mutableStateOf(false) }
    var groupSearchQuery by remember { mutableStateOf("") }
    var showPlaylistDrawer by remember { mutableStateOf(false) }

    var textInput by remember { mutableStateOf("") }
    var showEmojiBar by remember { mutableStateOf(false) }

    var showEditNameDialog by remember { mutableStateOf(false) }
    var newNameInput by remember { mutableStateOf("") }

    var showCreateGroupDialog by remember { mutableStateOf(false) }
    var newGroupName by remember { mutableStateOf("") }
    var newGroupDesc by remember { mutableStateOf("") }

    val listState = rememberLazyListState()

    // Smooth auto-scroll to the newest message whenever messages update
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AuraBackground)
            .imePadding()
    ) {
        // -------------------------------------------------------------
        // Top Header
        // -------------------------------------------------------------
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(AuraSurface)
                .padding(horizontal = 14.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "#${currentRoom.name}",
                        color = AuraTextPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Box(
                        modifier = Modifier
                            .size(7.dp)
                            .clip(CircleShape)
                            .background(AuraSuccess)
                    )
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 3.dp)
                ) {
                    // Clickable Room ID Pill with copy feedback
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(AuraSurfaceLight)
                            .clickable {
                                clipboardManager.setText(AnnotatedString(currentRoom.id))
                                Toast.makeText(context, "Group Code Copied: ${currentRoom.id}", Toast.LENGTH_SHORT).show()
                            }
                            .padding(horizontal = 7.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "Code: ${currentRoom.id}",
                            color = AuraAccent,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(
                            imageVector = Icons.Default.ContentCopy,
                            contentDescription = "Copy Group ID",
                            tint = AuraTextSecondary,
                            modifier = Modifier.size(11.dp)
                        )
                    }

                    Spacer(modifier = Modifier.width(8.dp))

                    // User Profile Handle (Tap to edit)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(AuraSurfaceLight)
                            .clickable {
                                newNameInput = profile?.name ?: ""
                                showEditNameDialog = true
                            }
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Person,
                            contentDescription = null,
                            tint = AuraTextMuted,
                            modifier = Modifier.size(11.dp)
                        )
                        Spacer(modifier = Modifier.width(3.dp))
                        Text(
                            text = profile?.name ?: "Listener",
                            color = AuraTextSecondary,
                            fontSize = 11.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                // Group Playlist Toggle Button
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (showPlaylistDrawer) AuraPrimary else AuraSurfaceLight)
                        .clickable { showPlaylistDrawer = !showPlaylistDrawer }
                        .padding(horizontal = 8.dp, vertical = 6.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.QueueMusic,
                        contentDescription = "Playlist",
                        tint = if (showPlaylistDrawer) AuraTextPrimary else AuraAccent,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(3.dp))
                    Text(
                        text = "${groupPlaylist.size}",
                        color = if (showPlaylistDrawer) AuraTextPrimary else AuraAccent,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(modifier = Modifier.width(6.dp))

                // Toggle Groups Search Button
                IconButton(
                    onClick = { showGroupDrawer = !showGroupDrawer },
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(if (showGroupDrawer) AuraPrimary else AuraSurfaceLight)
                ) {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Search Groups",
                        tint = if (showGroupDrawer) AuraTextPrimary else AuraAccent,
                        modifier = Modifier.size(16.dp)
                    )
                }

                Spacer(modifier = Modifier.width(6.dp))

                // Quick Create Group Button
                IconButton(
                    onClick = { showCreateGroupDialog = true },
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(AuraPrimary)
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "New Group",
                        tint = AuraTextPrimary,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        // -------------------------------------------------------------
        // Group Collaborative Playlist Drawer (Real-Time Synced)
        // -------------------------------------------------------------
        AnimatedVisibility(
            visible = showPlaylistDrawer,
            enter = expandVertically() + fadeIn(),
            exit = shrinkVertically() + fadeOut()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AuraSurface)
                    .border(1.dp, AuraCardBorder)
                    .padding(horizontal = 12.dp, vertical = 10.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.QueueMusic,
                            contentDescription = null,
                            tint = AuraAccent,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Group Playlist • ${groupPlaylist.size} tracks",
                            color = AuraTextPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                    }

                    if (currentSong != null) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(AuraPrimary.copy(alpha = 0.25f))
                                .clickable {
                                    ChatManager.addSongToGroupPlaylist(currentSong!!)
                                    Toast.makeText(context, "Added '${currentSong!!.title}' to group playlist!", Toast.LENGTH_SHORT).show()
                                }
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlaylistAdd,
                                contentDescription = null,
                                tint = AuraAccent,
                                modifier = Modifier.size(13.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "+ Add Playing Song",
                                color = AuraAccent,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                if (groupPlaylist.isEmpty()) {
                    Text(
                        text = "No tracks in group playlist yet. Anyone in the group can add songs!",
                        color = AuraTextMuted,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(vertical = 6.dp)
                    )
                } else {
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        items(groupPlaylist) { item ->
                            val isPlayingThis = currentSong?.id == item.song.id
                            Row(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(if (isPlayingThis) AuraPrimary.copy(alpha = 0.35f) else AuraSurfaceLight)
                                    .border(
                                        1.dp,
                                        if (isPlayingThis) AuraAccent else AuraCardBorder,
                                        RoundedCornerShape(10.dp)
                                    )
                                    .clickable {
                                        PlaybackManager.playSong(item.song)
                                        ChatManager.syncPlaybackToGroup(item.song, isPlaying = true)
                                    }
                                    .padding(8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                AsyncImage(
                                    model = item.song.thumbnailUrl,
                                    contentDescription = item.song.title,
                                    modifier = Modifier
                                        .size(36.dp)
                                        .clip(RoundedCornerShape(6.dp)),
                                    contentScale = ContentScale.Crop
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Column(modifier = Modifier.width(130.dp)) {
                                    Text(
                                        text = item.song.title,
                                        color = AuraTextPrimary,
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    Text(
                                        text = "Added by ${item.addedBy}",
                                        color = AuraAccent,
                                        fontSize = 10.sp,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                                IconButton(
                                    onClick = {
                                        PlaybackManager.playSong(item.song)
                                        ChatManager.syncPlaybackToGroup(item.song, isPlaying = true)
                                    },
                                    modifier = Modifier
                                        .size(28.dp)
                                        .clip(CircleShape)
                                        .background(AuraAccent)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.PlayArrow,
                                        contentDescription = "Play",
                                        tint = AuraBackground,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // Search & Groups Drawer (Collapsible)
        // -------------------------------------------------------------
        AnimatedVisibility(
            visible = showGroupDrawer,
            enter = expandVertically() + fadeIn(),
            exit = shrinkVertically() + fadeOut()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AuraSurfaceLight)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                OutlinedTextField(
                    value = groupSearchQuery,
                    onValueChange = { groupSearchQuery = it },
                    placeholder = {
                        Text(
                            "Search group or enter code (e.g. AURA-XXXX)...",
                            fontSize = 12.sp,
                            color = AuraTextMuted
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AuraAccent,
                        unfocusedBorderColor = AuraCardBorder,
                        focusedContainerColor = AuraBackground,
                        unfocusedContainerColor = AuraBackground,
                        focusedTextColor = AuraTextPrimary,
                        unfocusedTextColor = AuraTextPrimary
                    ),
                    leadingIcon = {
                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = null,
                            tint = AuraTextMuted,
                            modifier = Modifier.size(16.dp)
                        )
                    },
                    trailingIcon = {
                        if (groupSearchQuery.isNotBlank()) {
                            IconButton(onClick = { groupSearchQuery = "" }) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Clear",
                                    tint = AuraTextMuted,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    },
                    singleLine = true
                )

                val cleanQuery = groupSearchQuery.trim()
                val isCustomCode = cleanQuery.isNotBlank() && availableRooms.none { it.id.equals(cleanQuery, ignoreCase = true) }

                if (isCustomCode) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(AuraSurface)
                            .border(1.dp, AuraAccent.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
                            .clickable {
                                val name = profile?.name ?: "Listener"
                                val dob = profile?.dob ?: "01/01/2000"
                                ChatManager.joinRoomById(name, dob, cleanQuery)
                                groupSearchQuery = ""
                                showGroupDrawer = false
                                Toast.makeText(context, "Joined group: $cleanQuery", Toast.LENGTH_SHORT).show()
                            }
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Join Group Code: ${cleanQuery.uppercase()}",
                                color = AuraTextPrimary,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.sp
                            )
                            Text(
                                text = "Tap to connect instantly to this room",
                                color = AuraTextSecondary,
                                fontSize = 11.sp
                            )
                        }
                        Text(
                            text = "Join 🚀",
                            color = AuraTextPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp,
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(AuraPrimary)
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                val filtered = if (cleanQuery.isBlank()) {
                    availableRooms
                } else {
                    availableRooms.filter {
                        it.name.contains(cleanQuery, ignoreCase = true) ||
                        it.id.contains(cleanQuery, ignoreCase = true)
                    }
                }

                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    items(filtered) { room ->
                        val isCurrent = currentRoom.id == room.id
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(10.dp))
                                .background(if (isCurrent) AuraPrimary else AuraSurface)
                                .clickable {
                                    ChatManager.switchRoom(room)
                                    showGroupDrawer = false
                                }
                                .padding(horizontal = 12.dp, vertical = 7.dp)
                        ) {
                            Column {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = room.name,
                                        color = if (isCurrent) AuraTextPrimary else AuraTextSecondary,
                                        fontSize = 12.sp,
                                        fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Medium
                                    )
                                    if (isCurrent) {
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Box(
                                            modifier = Modifier
                                                .size(5.dp)
                                                .clip(CircleShape)
                                                .background(AuraSuccess)
                                        )
                                    }
                                }
                                Text(
                                    text = "ID: ${room.id}",
                                    color = if (isCurrent) AuraTextPrimary.copy(alpha = 0.8f) else AuraAccent,
                                    fontSize = 10.sp
                                )
                            }
                        }
                    }
                }
            }
        }

        // -------------------------------------------------------------
        // Messages Thread (Smooth Scroll & Full History Swipe-Up)
        // -------------------------------------------------------------
        LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 14.dp),
            contentPadding = PaddingValues(top = 10.dp, bottom = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(AuraSurface.copy(alpha = 0.7f))
                        .padding(10.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "🎧 Real-Time Live Music Group",
                            color = AuraAccent,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Collaborative Playlist Active: anyone in this group can add songs and chat in real time.",
                            color = AuraTextMuted,
                            fontSize = 11.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }

            items(messages, key = { it.id }) { message ->
                MessageBubble(
                    message = message,
                    onReact = { emoji ->
                        ChatManager.addReaction(message.id, emoji)
                    },
                    onAddToPlaylist = { song ->
                        ChatManager.addSongToGroupPlaylist(song)
                        Toast.makeText(context, "Added '${song.title}' to group playlist!", Toast.LENGTH_SHORT).show()
                    }
                )
            }
        }

        // -------------------------------------------------------------
        // Bottom Input Container
        // -------------------------------------------------------------
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AuraSurface)
                .padding(horizontal = 12.dp, vertical = 6.dp)
        ) {
            // "Share & Add to Group Playlist" chip
            if (currentSong != null) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(AuraPrimary.copy(alpha = 0.2f))
                        .clickable {
                            ChatManager.addSongToGroupPlaylist(currentSong!!)
                            Toast.makeText(context, "Shared to Group Playlist: ${currentSong!!.title}", Toast.LENGTH_SHORT).show()
                        }
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.PlaylistAdd,
                        contentDescription = null,
                        tint = AuraAccent,
                        modifier = Modifier.size(15.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Add to Group Playlist: ${currentSong!!.title}",
                        color = AuraAccent,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = "+ Add 🚀",
                        color = AuraTextPrimary,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(AuraPrimary)
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
            }

            // Quick Emoji Drawer
            if (showEmojiBar) {
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 6.dp)
                ) {
                    items(ChatManager.popularEmojis) { emoji ->
                        Box(
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(AuraSurfaceLight)
                                .clickable {
                                    textInput += emoji
                                }
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(text = emoji, fontSize = 18.sp)
                        }
                    }
                }
            }

            // Textfield & Send Button Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(
                    onClick = { showEmojiBar = !showEmojiBar },
                    modifier = Modifier.size(38.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.EmojiEmotions,
                        contentDescription = "Emojis",
                        tint = if (showEmojiBar) AuraAccent else AuraTextSecondary,
                        modifier = Modifier.size(22.dp)
                    )
                }

                Spacer(modifier = Modifier.width(4.dp))

                OutlinedTextField(
                    value = textInput,
                    onValueChange = { textInput = it },
                    placeholder = { Text("Message #${currentRoom.name}...", color = AuraTextMuted, fontSize = 13.sp) },
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(22.dp)),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AuraAccent,
                        unfocusedBorderColor = AuraSurfaceLight,
                        focusedContainerColor = AuraBackground,
                        unfocusedContainerColor = AuraBackground,
                        focusedTextColor = AuraTextPrimary,
                        unfocusedTextColor = AuraTextPrimary
                    ),
                    singleLine = true
                )

                Spacer(modifier = Modifier.width(6.dp))

                IconButton(
                    onClick = {
                        val clean = textInput.trim()
                        if (clean.isNotBlank()) {
                            ChatManager.sendMessage(clean)
                            textInput = ""
                        }
                    },
                    enabled = textInput.isNotBlank(),
                    modifier = Modifier
                        .size(42.dp)
                        .clip(CircleShape)
                        .background(if (textInput.isNotBlank()) AuraPrimary else AuraSurfaceLight)
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = if (textInput.isNotBlank()) AuraTextPrimary else AuraTextMuted,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }

    // -------------------------------------------------------------
    // Edit User Handle Dialog
    // -------------------------------------------------------------
    if (showEditNameDialog) {
        AlertDialog(
            onDismissRequest = { showEditNameDialog = false },
            title = { Text("Edit Display Handle", color = AuraTextPrimary, fontWeight = FontWeight.Bold) },
            text = {
                OutlinedTextField(
                    value = newNameInput,
                    onValueChange = { newNameInput = it },
                    label = { Text("Display Name") },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AuraAccent,
                        unfocusedBorderColor = AuraCardBorder,
                        focusedTextColor = AuraTextPrimary,
                        unfocusedTextColor = AuraTextPrimary
                    )
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (newNameInput.isNotBlank()) {
                            ChatManager.updateProfileName(newNameInput)
                        }
                        showEditNameDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AuraPrimary)
                ) {
                    Text("Save", color = AuraTextPrimary)
                }
            },
            dismissButton = {
                TextButton(onClick = { showEditNameDialog = false }) {
                    Text("Cancel", color = AuraTextSecondary)
                }
            },
            containerColor = AuraSurface
        )
    }

    // -------------------------------------------------------------
    // Create Group Dialog
    // -------------------------------------------------------------
    if (showCreateGroupDialog) {
        AlertDialog(
            onDismissRequest = { showCreateGroupDialog = false },
            title = { Text("Create Music Group", color = AuraTextPrimary, fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text(
                        "You will get a unique Room Code (e.g. AURA-XXXX) that your friends can search and join.",
                        color = AuraTextSecondary,
                        fontSize = 12.sp
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    OutlinedTextField(
                        value = newGroupName,
                        onValueChange = { newGroupName = it },
                        placeholder = { Text("Group Name (e.g. Synthwave Club)") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AuraAccent,
                            unfocusedBorderColor = AuraCardBorder,
                            focusedTextColor = AuraTextPrimary,
                            unfocusedTextColor = AuraTextPrimary
                        )
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = newGroupDesc,
                        onValueChange = { newGroupDesc = it },
                        placeholder = { Text("Description (Optional)") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AuraAccent,
                            unfocusedBorderColor = AuraCardBorder,
                            focusedTextColor = AuraTextPrimary,
                            unfocusedTextColor = AuraTextPrimary
                        )
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val name = profile?.name ?: "Listener"
                        val dob = profile?.dob ?: "01/01/2000"
                        val created = ChatManager.createAndJoinRoom(
                            userName = name,
                            userDob = dob,
                            roomName = newGroupName.ifBlank { "Aura Lounge" },
                            description = newGroupDesc
                        )
                        newGroupName = ""
                        newGroupDesc = ""
                        showCreateGroupDialog = false
                        Toast.makeText(context, "Group Created! Code: ${created.id}", Toast.LENGTH_LONG).show()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AuraPrimary)
                ) {
                    Text("Create & Join 🚀", color = AuraTextPrimary, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showCreateGroupDialog = false }) {
                    Text("Cancel", color = AuraTextSecondary)
                }
            },
            containerColor = AuraSurface
        )
    }
}

@Composable
fun MessageBubble(
    message: ChatMessage,
    onReact: (String) -> Unit,
    onAddToPlaylist: (com.auramusic.app.data.models.Song) -> Unit
) {
    val isMe = message.isFromMe
    var showReactPicker by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isMe) Alignment.End else Alignment.Start
    ) {
        if (!isMe && message.senderName.isNotBlank()) {
            Text(
                text = message.senderName,
                color = AuraAccent,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(start = 6.dp, bottom = 2.dp)
            )
        }

        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(16.dp))
                .background(if (isMe) AuraPrimary else AuraSurface)
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Column {
                if (message.text.isNotBlank()) {
                    Text(
                        text = message.text,
                        color = AuraTextPrimary,
                        fontSize = 14.sp
                    )
                }

                // Shared Song Card
                if (message.sharedSong != null) {
                    val song = message.sharedSong
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(AuraBackground.copy(alpha = 0.5f))
                            .padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        AsyncImage(
                            model = song.thumbnailUrl,
                            contentDescription = song.title,
                            modifier = Modifier
                                .size(44.dp)
                                .clip(RoundedCornerShape(6.dp)),
                            contentScale = ContentScale.Crop
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = song.title,
                                color = AuraTextPrimary,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = song.artist,
                                color = AuraTextSecondary,
                                fontSize = 10.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }

                        // Add to Playlist Button
                        IconButton(
                            onClick = { onAddToPlaylist(song) },
                            modifier = Modifier
                                .size(30.dp)
                                .clip(CircleShape)
                                .background(AuraSurfaceLight)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlaylistAdd,
                                contentDescription = "Add to Playlist",
                                tint = AuraAccent,
                                modifier = Modifier.size(17.dp)
                            )
                        }

                        Spacer(modifier = Modifier.width(4.dp))

                        // Play Button
                        IconButton(
                            onClick = {
                                PlaybackManager.playSong(song)
                                ChatManager.syncPlaybackToGroup(song, isPlaying = true)
                            },
                            modifier = Modifier
                                .size(32.dp)
                                .clip(CircleShape)
                                .background(AuraAccent)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = "Play",
                                tint = AuraBackground,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }
        }

        // Reactions Row
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
        ) {
            for ((emoji, count) in message.reactions) {
                if (count > 0) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .padding(end = 4.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(AuraSurfaceLight)
                            .clickable { onReact(emoji) }
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(text = emoji, fontSize = 11.sp)
                        Spacer(modifier = Modifier.width(2.dp))
                        Text(
                            text = "$count",
                            color = AuraTextSecondary,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Quick React "+" button
            Box {
                IconButton(
                    onClick = { showReactPicker = !showReactPicker },
                    modifier = Modifier.size(24.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Add reaction",
                        tint = AuraTextMuted,
                        modifier = Modifier.size(13.dp)
                    )
                }

                DropdownMenu(
                    expanded = showReactPicker,
                    onDismissRequest = { showReactPicker = false },
                    modifier = Modifier.background(AuraSurface)
                ) {
                    Row(modifier = Modifier.padding(4.dp)) {
                        for (emoji in ChatManager.popularEmojis) {
                            Text(
                                text = emoji,
                                fontSize = 20.sp,
                                modifier = Modifier
                                    .padding(horizontal = 6.dp)
                                    .clickable {
                                        onReact(emoji)
                                        showReactPicker = false
                                    }
                            )
                        }
                    }
                }
            }
        }
    }
}
