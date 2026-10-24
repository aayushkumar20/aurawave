package com.auramusic.app.ui.screens

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cake
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.EmojiEmotions
import androidx.compose.material.icons.filled.MeetingRoom
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.auramusic.app.data.models.ChatMessage
import com.auramusic.app.data.models.ChatRoom
import com.auramusic.app.data.repository.ChatManager
import com.auramusic.app.player.PlaybackManager
import com.auramusic.app.ui.theme.AuraAccent
import com.auramusic.app.ui.theme.AuraBackground
import com.auramusic.app.ui.theme.AuraCardBorder
import com.auramusic.app.ui.theme.AuraPink
import com.auramusic.app.ui.theme.AuraPrimary
import com.auramusic.app.ui.theme.AuraSuccess
import com.auramusic.app.ui.theme.AuraSurface
import com.auramusic.app.ui.theme.AuraSurfaceLight
import com.auramusic.app.ui.theme.AuraTextMuted
import com.auramusic.app.ui.theme.AuraTextPrimary
import com.auramusic.app.ui.theme.AuraTextSecondary

@Composable
fun ChatScreen() {
    val profile by ChatManager.currentProfile.collectAsState()
    val currentRoom by ChatManager.currentRoom.collectAsState()
    val messages by ChatManager.messages.collectAsState()
    val currentSong by PlaybackManager.currentSong.collectAsState()

    var inputName by remember { mutableStateOf("") }
    var inputDob by remember { mutableStateOf("") }
    var selectedRoom by remember { mutableStateOf(ChatManager.defaultRooms[0]) }

    var textInput by remember { mutableStateOf("") }
    var showEmojiBar by remember { mutableStateOf(false) }
    var showRoomSwitchModal by remember { mutableStateOf(false) }

    if (profile == null) {
        // Room Entry Gate (User requested: Just enter Name and DOB to join chat)
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(AuraBackground)
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(AuraSurface)
                    .border(1.dp, AuraCardBorder, RoundedCornerShape(20.dp))
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    modifier = Modifier
                        .size(60.dp)
                        .clip(CircleShape)
                        .background(AuraPrimary.copy(alpha = 0.2f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.MeetingRoom,
                        contentDescription = null,
                        tint = AuraAccent,
                        modifier = Modifier.size(32.dp)
                    )
                }

                Spacer(modifier = Modifier.height(14.dp))

                Text(
                    text = "Join Music Chat Room",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = AuraTextPrimary
                )

                Text(
                    text = "Enter your Name & DOB to jump right into the live room",
                    fontSize = 12.sp,
                    color = AuraTextMuted,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 4.dp, bottom = 18.dp)
                )

                // Name Input
                OutlinedTextField(
                    value = inputName,
                    onValueChange = { inputName = it },
                    placeholder = { Text("Your Name", color = AuraTextMuted) },
                    leadingIcon = {
                        Icon(Icons.Default.Person, contentDescription = null, tint = AuraAccent)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AuraAccent,
                        unfocusedBorderColor = AuraSurfaceLight,
                        focusedTextColor = AuraTextPrimary,
                        unfocusedTextColor = AuraTextPrimary
                    )
                )

                Spacer(modifier = Modifier.height(12.dp))

                // DOB Input
                OutlinedTextField(
                    value = inputDob,
                    onValueChange = { inputDob = it },
                    placeholder = { Text("Date of Birth (e.g. 14/05/2002)", color = AuraTextMuted) },
                    leadingIcon = {
                        Icon(Icons.Default.Cake, contentDescription = null, tint = AuraPink)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AuraAccent,
                        unfocusedBorderColor = AuraSurfaceLight,
                        focusedTextColor = AuraTextPrimary,
                        unfocusedTextColor = AuraTextPrimary
                    )
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Select Room Chips
                Text(
                    text = "Choose Room:",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AuraTextSecondary,
                    modifier = Modifier.align(Alignment.Start)
                )

                Spacer(modifier = Modifier.height(6.dp))

                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    items(ChatManager.defaultRooms) { r ->
                        val isSel = selectedRoom.id == r.id
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (isSel) AuraPrimary else AuraSurfaceLight)
                                .clickable { selectedRoom = r }
                                .padding(horizontal = 10.dp, vertical = 6.dp)
                        ) {
                            Text(
                                text = r.name,
                                fontSize = 11.sp,
                                fontWeight = if (isSel) FontWeight.Bold else FontWeight.Normal,
                                color = AuraTextPrimary
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                Button(
                    onClick = {
                        if (inputName.isNotBlank() && inputDob.isNotBlank()) {
                            ChatManager.joinRoom(inputName, inputDob, selectedRoom)
                        }
                    },
                    enabled = inputName.isNotBlank() && inputDob.isNotBlank(),
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = AuraPrimary)
                ) {
                    Text("Enter Room 🚀", color = AuraTextPrimary, fontWeight = FontWeight.Bold)
                }
            }
        }
        return
    }

    // Active Room View
    val activeProfile = profile!!

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AuraBackground)
    ) {
        // Room Top Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(AuraSurface)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "#${currentRoom.name}",
                        color = AuraTextPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(AuraSuccess)
                    )
                }
                Text(
                    text = "${activeProfile.name} • ${currentRoom.description}",
                    color = AuraTextMuted,
                    fontSize = 11.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(
                    onClick = { showRoomSwitchModal = !showRoomSwitchModal },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.SwapHoriz,
                        contentDescription = "Switch Room",
                        tint = AuraAccent,
                        modifier = Modifier.size(22.dp)
                    )
                }

                // Firebase Status Pill
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(AuraPrimary.copy(alpha = 0.2f))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.CloudDone,
                        contentDescription = "Firebase DB",
                        tint = AuraAccent,
                        modifier = Modifier.size(13.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Firebase",
                        color = AuraAccent,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        // Room Switcher Bar (Expandable)
        if (showRoomSwitchModal) {
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AuraSurfaceLight)
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(ChatManager.defaultRooms) { room ->
                    val isCurrent = currentRoom.id == room.id
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(if (isCurrent) AuraPrimary else AuraSurface)
                            .clickable {
                                ChatManager.switchRoom(room)
                                showRoomSwitchModal = false
                            }
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Text(
                            text = room.name,
                            color = AuraTextPrimary,
                            fontSize = 12.sp,
                            fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal
                        )
                    }
                }
            }
        }

        // Message Thread
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 16.dp),
            contentPadding = PaddingValues(vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(messages) { message ->
                MessageBubble(
                    message = message,
                    onReact = { emoji ->
                        ChatManager.addReaction(message.id, emoji)
                    }
                )
            }
        }

        // Bottom Input Row
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AuraSurface)
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            // "Share Current Playing Song" chip
            if (currentSong != null) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(AuraPrimary.copy(alpha = 0.2f))
                        .clickable {
                            ChatManager.sendMessage(
                                text = "🎧 Check out this live song: ${currentSong!!.title}",
                                sharedSong = currentSong
                            )
                        }
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.MusicNote,
                        contentDescription = null,
                        tint = AuraAccent,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Share playing song: ${currentSong!!.title}",
                        color = AuraAccent,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
            }

            // Quick Emoji Tray
            if (showEmojiBar) {
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp)
                ) {
                    items(ChatManager.popularEmojis) { emoji ->
                        Box(
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(AuraSurfaceLight)
                                .clickable {
                                    textInput += emoji
                                }
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(text = emoji, fontSize = 20.sp)
                        }
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(
                    onClick = { showEmojiBar = !showEmojiBar },
                    modifier = Modifier.size(40.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.EmojiEmotions,
                        contentDescription = "Emojis",
                        tint = if (showEmojiBar) AuraAccent else AuraTextSecondary,
                        modifier = Modifier.size(24.dp)
                    )
                }

                Spacer(modifier = Modifier.width(4.dp))

                OutlinedTextField(
                    value = textInput,
                    onValueChange = { textInput = it },
                    placeholder = { Text("Message #${currentRoom.name}...", color = AuraTextMuted) },
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(24.dp)),
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

                Spacer(modifier = Modifier.width(8.dp))

                IconButton(
                    onClick = {
                        if (textInput.isNotBlank()) {
                            ChatManager.sendMessage(textInput)
                            textInput = ""
                        }
                    },
                    modifier = Modifier
                        .size(46.dp)
                        .clip(CircleShape)
                        .background(AuraPrimary)
                ) {
                    Icon(
                        imageVector = Icons.Default.Send,
                        contentDescription = "Send",
                        tint = AuraTextPrimary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}

@Composable
fun MessageBubble(
    message: ChatMessage,
    onReact: (String) -> Unit
) {
    val isMe = message.isFromMe
    var showReactionMenu by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isMe) Alignment.End else Alignment.Start
    ) {
        if (!isMe && message.senderName.isNotBlank()) {
            Text(
                text = message.senderName,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = AuraAccent,
                modifier = Modifier.padding(start = 6.dp, bottom = 2.dp)
            )
        }

        Box(
            modifier = Modifier
                .clip(
                    RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = if (isMe) 16.dp else 4.dp,
                        bottomEnd = if (isMe) 4.dp else 16.dp
                    )
                )
                .background(if (isMe) AuraPrimary else AuraSurface)
                .clickable { showReactionMenu = !showReactionMenu }
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Column {
                if (message.text.isNotBlank()) {
                    Text(
                        text = message.text,
                        color = AuraTextPrimary,
                        fontSize = 14.sp
                    )
                }

                message.sharedSong?.let { song ->
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth(0.85f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(AuraBackground.copy(alpha = 0.7f))
                            .padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        AsyncImage(
                            model = song.thumbnailUrl,
                            contentDescription = song.title,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(44.dp)
                                .clip(RoundedCornerShape(6.dp))
                        )

                        Spacer(modifier = Modifier.width(8.dp))

                        Column(modifier = Modifier.weight(1f)) {
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
                                color = AuraTextSecondary,
                                fontSize = 11.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }

                        // Play Now Button
                        IconButton(
                            onClick = { PlaybackManager.playSong(song) },
                            modifier = Modifier
                                .size(32.dp)
                                .clip(CircleShape)
                                .background(AuraAccent)
                        ) {
                            Icon(
                                imageVector = Icons.Default.PlayArrow,
                                contentDescription = "Play Shared Song",
                                tint = AuraBackground,
                                modifier = Modifier.size(20.dp)
                            )
                        }

                        Spacer(modifier = Modifier.width(4.dp))

                        // Play Next in Queue Button
                        IconButton(
                            onClick = { PlaybackManager.playNext(song) },
                            modifier = Modifier.size(32.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.QueueMusic,
                                contentDescription = "Play Next",
                                tint = AuraTextSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }
        }

        // Active Reactions Pill Row
        if (message.reactions.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .padding(top = 4.dp, start = if (isMe) 0.dp else 4.dp, end = if (isMe) 4.dp else 0.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                message.reactions.forEach { (emoji, count) ->
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .background(AuraSurfaceLight)
                            .clickable { onReact(emoji) }
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = "$emoji $count",
                            fontSize = 11.sp,
                            color = AuraTextPrimary
                        )
                    }
                }
            }
        }

        // Quick Reaction Picker Menu when tapped
        if (showReactionMenu) {
            Row(
                modifier = Modifier
                    .padding(top = 6.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(AuraSurfaceLight)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                listOf("❤️", "🔥", "🎧", "👏", "😂", "🚀").forEach { emoji ->
                    Text(
                        text = emoji,
                        fontSize = 18.sp,
                        modifier = Modifier
                            .clickable {
                                onReact(emoji)
                                showReactionMenu = false
                            }
                            .padding(2.dp)
                    )
                }
            }
        }
    }
}

