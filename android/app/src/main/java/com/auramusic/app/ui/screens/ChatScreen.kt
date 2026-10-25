package com.auramusic.app.ui.screens

import android.widget.Toast
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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Cake
import androidx.compose.material.icons.filled.CloudDone
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.EmojiEmotions
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.GroupAdd
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Login
import androidx.compose.material.icons.filled.MeetingRoom
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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

enum class RoomJoinMode {
    BROWSE, JOIN_BY_ID, CREATE_ROOM
}

@Composable
fun ChatScreen() {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current

    val profile by ChatManager.currentProfile.collectAsState()
    val currentRoom by ChatManager.currentRoom.collectAsState()
    val availableRooms by ChatManager.availableRooms.collectAsState()
    val messages by ChatManager.messages.collectAsState()
    val currentSong by PlaybackManager.currentSong.collectAsState()

    var inputName by remember { mutableStateOf("") }
    var inputDob by remember { mutableStateOf("") }
    var selectedRoom by remember { mutableStateOf(availableRooms.firstOrNull() ?: ChatManager.defaultRooms[0]) }

    var joinMode by remember { mutableStateOf(RoomJoinMode.BROWSE) }
    var inputRoomIdToJoin by remember { mutableStateOf("") }
    var inputCustomRoomName by remember { mutableStateOf("") }
    var inputCustomRoomDesc by remember { mutableStateOf("") }

    var textInput by remember { mutableStateOf("") }
    var showEmojiBar by remember { mutableStateOf(false) }
    var showRoomSwitchModal by remember { mutableStateOf(false) }
    var showCreateGroupDialog by remember { mutableStateOf(false) }
    var showJoinByIdDialog by remember { mutableStateOf(false) }

    if (profile == null) {
        // Room Entry Gate
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(AuraBackground)
                .padding(20.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(AuraSurface)
                    .border(1.dp, AuraCardBorder, RoundedCornerShape(20.dp))
                    .padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    modifier = Modifier
                        .size(54.dp)
                        .clip(CircleShape)
                        .background(AuraPrimary.copy(alpha = 0.2f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.MeetingRoom,
                        contentDescription = null,
                        tint = AuraAccent,
                        modifier = Modifier.size(28.dp)
                    )
                }

                Spacer(modifier = Modifier.height(10.dp))

                Text(
                    text = "Aura Live Chat & Groups",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = AuraTextPrimary
                )

                Text(
                    text = "Listen together, share music & chat in real time",
                    fontSize = 12.sp,
                    color = AuraTextMuted,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 4.dp, bottom = 14.dp)
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

                Spacer(modifier = Modifier.height(10.dp))

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

                Spacer(modifier = Modifier.height(14.dp))

                // Mode Tabs (Browse Public, Join with ID, Create Group)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(AuraSurfaceLight)
                        .padding(3.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    val tabs = listOf(
                        RoomJoinMode.BROWSE to "Rooms",
                        RoomJoinMode.JOIN_BY_ID to "Join with ID",
                        RoomJoinMode.CREATE_ROOM to "+ Create Group"
                    )
                    tabs.forEach { (mode, label) ->
                        val isSelected = joinMode == mode
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(10.dp))
                                .background(if (isSelected) AuraPrimary else AuraSurfaceLight)
                                .clickable { joinMode = mode }
                                .padding(vertical = 8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = label,
                                fontSize = 11.sp,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                color = if (isSelected) AuraTextPrimary else AuraTextMuted,
                                maxLines = 1
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                when (joinMode) {
                    RoomJoinMode.BROWSE -> {
                        Text(
                            text = "Select a Room to Enter:",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = AuraTextSecondary,
                            modifier = Modifier.align(Alignment.Start)
                        )

                        Spacer(modifier = Modifier.height(8.dp))

                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            items(availableRooms) { r ->
                                val isSel = selectedRoom.id == r.id
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(if (isSel) AuraPrimary else AuraSurfaceLight)
                                        .clickable { selectedRoom = r }
                                        .padding(horizontal = 12.dp, vertical = 8.dp)
                                ) {
                                    Column {
                                        Text(
                                            text = r.name,
                                            fontSize = 12.sp,
                                            fontWeight = if (isSel) FontWeight.Bold else FontWeight.Normal,
                                            color = AuraTextPrimary
                                        )
                                        Text(
                                            text = "ID: ${r.id}",
                                            fontSize = 10.sp,
                                            color = if (isSel) AuraAccent else AuraTextMuted
                                        )
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(18.dp))

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
                            Text("Enter #${selectedRoom.name} 🚀", color = AuraTextPrimary, fontWeight = FontWeight.Bold)
                        }
                    }

                    RoomJoinMode.JOIN_BY_ID -> {
                        OutlinedTextField(
                            value = inputRoomIdToJoin,
                            onValueChange = { inputRoomIdToJoin = it.uppercase() },
                            placeholder = { Text("Enter Group ID (e.g. AURA-4821)", color = AuraTextMuted) },
                            leadingIcon = {
                                Icon(Icons.Default.Key, contentDescription = null, tint = AuraAccent)
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

                        Spacer(modifier = Modifier.height(18.dp))

                        Button(
                            onClick = {
                                if (inputName.isNotBlank() && inputDob.isNotBlank() && inputRoomIdToJoin.isNotBlank()) {
                                    ChatManager.joinRoomById(inputName, inputDob, inputRoomIdToJoin)
                                }
                            },
                            enabled = inputName.isNotBlank() && inputDob.isNotBlank() && inputRoomIdToJoin.isNotBlank(),
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = AuraAccent)
                        ) {
                            Text("Join Group via ID 🚀", color = AuraBackground, fontWeight = FontWeight.Bold)
                        }
                    }

                    RoomJoinMode.CREATE_ROOM -> {
                        OutlinedTextField(
                            value = inputCustomRoomName,
                            onValueChange = { inputCustomRoomName = it },
                            placeholder = { Text("New Group Name (e.g. Beats & Vibes)", color = AuraTextMuted) },
                            leadingIcon = {
                                Icon(Icons.Default.GroupAdd, contentDescription = null, tint = AuraAccent)
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

                        Spacer(modifier = Modifier.height(18.dp))

                        Button(
                            onClick = {
                                if (inputName.isNotBlank() && inputDob.isNotBlank() && inputCustomRoomName.isNotBlank()) {
                                    val newRoom = ChatManager.createAndJoinRoom(inputName, inputDob, inputCustomRoomName)
                                    Toast.makeText(context, "Group Created! ID: ${newRoom.id}", Toast.LENGTH_LONG).show()
                                }
                            },
                            enabled = inputName.isNotBlank() && inputDob.isNotBlank() && inputCustomRoomName.isNotBlank(),
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = AuraPrimary)
                        ) {
                            Text("Create & Join Group 🚀", color = AuraTextPrimary, fontWeight = FontWeight.Bold)
                        }
                    }
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

                // Clickable Unique Group ID Pill
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .padding(top = 2.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(AuraSurfaceLight)
                        .clickable {
                            clipboardManager.setText(AnnotatedString(currentRoom.id))
                            Toast.makeText(context, "Group ID copied: ${currentRoom.id}", Toast.LENGTH_SHORT).show()
                        }
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                ) {
                    Text(
                        text = "ID: ${currentRoom.id}",
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
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                // Switch / Manage Room
                IconButton(
                    onClick = { showRoomSwitchModal = !showRoomSwitchModal },
                    modifier = Modifier.size(34.dp)
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
                        modifier = Modifier.size(12.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "Live",
                        color = AuraAccent,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        // Room Switcher Bar (Expandable)
        if (showRoomSwitchModal) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AuraSurfaceLight)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Switch or Create Group:",
                        fontSize = 11.sp,
                        color = AuraTextSecondary,
                        fontWeight = FontWeight.SemiBold
                    )

                    Row {
                        Text(
                            text = "+ Create",
                            color = AuraAccent,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier
                                .clickable {
                                    showCreateGroupDialog = true
                                    showRoomSwitchModal = false
                                }
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Join with ID",
                            color = AuraPink,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier
                                .clickable {
                                    showJoinByIdDialog = true
                                    showRoomSwitchModal = false
                                }
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(6.dp))

                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    items(availableRooms) { room ->
                        val isCurrent = currentRoom.id == room.id
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(10.dp))
                                .background(if (isCurrent) AuraPrimary else AuraSurface)
                                .clickable {
                                    ChatManager.switchRoom(room)
                                    showRoomSwitchModal = false
                                }
                                .padding(horizontal = 10.dp, vertical = 5.dp)
                        ) {
                            Text(
                                text = "${room.name} (${room.id})",
                                color = AuraTextPrimary,
                                fontSize = 11.sp,
                                fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal
                            )
                        }
                    }
                }
            }
        }

        // Message Thread
        LazyColumn(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 14.dp),
            contentPadding = PaddingValues(vertical = 10.dp),
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
                .padding(horizontal = 12.dp, vertical = 8.dp)
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
                        modifier = Modifier.size(15.dp)
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
                Spacer(modifier = Modifier.height(6.dp))
            }

            // Quick Emoji Tray
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
                    placeholder = { Text("Message #${currentRoom.name}...", color = AuraTextMuted) },
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
                        if (textInput.isNotBlank()) {
                            ChatManager.sendMessage(textInput)
                            textInput = ""
                        }
                    },
                    modifier = Modifier
                        .size(42.dp)
                        .clip(CircleShape)
                        .background(AuraPrimary)
                ) {
                    Icon(
                        imageVector = Icons.Default.Send,
                        contentDescription = "Send",
                        tint = AuraTextPrimary,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }

    // Create Group Dialog
    if (showCreateGroupDialog) {
        var newGroupName by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showCreateGroupDialog = false },
            title = { Text("Create New Group", color = AuraTextPrimary, fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text("Enter a name for your group. A unique Group ID will be generated so your friends can join instantly.", color = AuraTextMuted, fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(10.dp))
                    OutlinedTextField(
                        value = newGroupName,
                        onValueChange = { newGroupName = it },
                        label = { Text("Group Name") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AuraAccent,
                            unfocusedBorderColor = AuraSurfaceLight,
                            focusedTextColor = AuraTextPrimary,
                            unfocusedTextColor = AuraTextPrimary
                        )
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (newGroupName.isNotBlank()) {
                            val room = ChatManager.createRoom(newGroupName)
                            ChatManager.switchRoom(room)
                            clipboardManager.setText(AnnotatedString(room.id))
                            Toast.makeText(context, "Group Created! ID copied: ${room.id}", Toast.LENGTH_LONG).show()
                            showCreateGroupDialog = false
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AuraPrimary)
                ) {
                    Text("Create & Join", color = AuraTextPrimary)
                }
            },
            dismissButton = {
                TextButton(onClick = { showCreateGroupDialog = false }) {
                    Text("Cancel", color = AuraTextMuted)
                }
            },
            containerColor = AuraSurface
        )
    }

    // Join Group by ID Dialog
    if (showJoinByIdDialog) {
        var inputId by remember { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = { showJoinByIdDialog = false },
            title = { Text("Join Group with ID", color = AuraTextPrimary, fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text("Enter the unique Group ID shared by your friend (e.g. AURA-4821)", color = AuraTextMuted, fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(10.dp))
                    OutlinedTextField(
                        value = inputId,
                        onValueChange = { inputId = it.uppercase() },
                        label = { Text("Group ID") },
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = AuraAccent,
                            unfocusedBorderColor = AuraSurfaceLight,
                            focusedTextColor = AuraTextPrimary,
                            unfocusedTextColor = AuraTextPrimary
                        )
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (inputId.isNotBlank() && profile != null) {
                            ChatManager.joinRoomById(profile!!.name, profile!!.dob, inputId)
                            Toast.makeText(context, "Joined Group: ${inputId.uppercase()}", Toast.LENGTH_SHORT).show()
                            showJoinByIdDialog = false
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AuraAccent)
                ) {
                    Text("Join Group", color = AuraBackground, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showJoinByIdDialog = false }) {
                    Text("Cancel", color = AuraTextMuted)
                }
            },
            containerColor = AuraSurface
        )
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
