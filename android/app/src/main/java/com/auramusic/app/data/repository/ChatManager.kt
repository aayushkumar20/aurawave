package com.auramusic.app.data.repository

import com.auramusic.app.data.models.ChatMessage
import com.auramusic.app.data.models.ChatRoom
import com.auramusic.app.data.models.GroupPlaylistItem
import com.auramusic.app.data.models.GroupSyncPacket
import com.auramusic.app.data.models.RoomProfile
import com.auramusic.app.data.models.Song
import com.auramusic.app.player.PlaybackManager
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

object ChatManager {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()
    private var syncJob: Job? = null

    // Configured Firebase project endpoint
    var firebaseDatabaseUrl = "https://linuxvm-d10a3-default-rtdb.firebaseio.com"

    val popularEmojis = listOf("❤️", "🔥", "🎧", "👏", "😂", "😮", "🚀", "✨", "🎵")

    val defaultRooms = listOf(
        ChatRoom("room_global", "Global Music Lounge", "Live music discussions & real-time song sharing", 18),
        ChatRoom("room_late_night", "Late Night Vibes", "Lo-fi beats, synthwave, and midnight conversations", 9),
        ChatRoom("room_edm", "Bass & Electronic", "Fast tempos, heavy drops, and hype tracks", 14)
    )

    private val _availableRooms = MutableStateFlow<List<ChatRoom>>(defaultRooms)
    val availableRooms: StateFlow<List<ChatRoom>> = _availableRooms.asStateFlow()

    private val _currentProfile = MutableStateFlow<RoomProfile?>(null)
    val currentProfile: StateFlow<RoomProfile?> = _currentProfile.asStateFlow()

    private val _currentRoom = MutableStateFlow(defaultRooms[0])
    val currentRoom: StateFlow<ChatRoom> = _currentRoom.asStateFlow()

    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()

    // Real-Time Shared Group Playlist
    private val _groupPlaylist = MutableStateFlow<List<GroupPlaylistItem>>(emptyList())
    val groupPlaylist: StateFlow<List<GroupPlaylistItem>> = _groupPlaylist.asStateFlow()

    init {
        val randomNum = (1000..9999).random()
        val defaultHandle = "Listener_$randomNum"
        joinRoom(defaultHandle, "01/01/2000", defaultRooms[0])
    }

    fun updateProfileName(newName: String) {
        val clean = newName.trim()
        if (clean.isBlank()) return
        val current = _currentProfile.value
        val dob = current?.dob ?: "01/01/2000"
        _currentProfile.value = RoomProfile(name = clean, dob = dob)
    }

    fun createRoom(name: String, description: String = ""): ChatRoom {
        val trimmed = name.trim().ifBlank { "Aura Lounge" }
        val randomNum = (1000..9999).random()
        val uniqueId = "AURA-$randomNum"
        val desc = description.trim().ifBlank { "Live Group • Code: $uniqueId" }

        val newRoom = ChatRoom(
            id = uniqueId,
            name = trimmed,
            description = desc,
            activeListeners = 1
        )

        val current = _availableRooms.value.toMutableList()
        current.add(0, newRoom)
        _availableRooms.value = current
        return newRoom
    }

    fun joinRoomById(name: String, dob: String, roomId: String): Boolean {
        val cleanId = roomId.trim().uppercase()
        if (cleanId.isBlank()) return false

        val existing = _availableRooms.value.find { it.id.equals(cleanId, ignoreCase = true) }
        val targetRoom = existing ?: ChatRoom(
            id = cleanId,
            name = cleanId,
            description = "Group Room • ID: $cleanId",
            activeListeners = 1
        )

        joinRoom(name, dob, targetRoom)
        return true
    }

    fun createAndJoinRoom(userName: String, userDob: String, roomName: String, description: String = ""): ChatRoom {
        val newRoom = createRoom(roomName, description)
        joinRoom(userName, userDob, newRoom)
        return newRoom
    }

    fun joinRoom(name: String, dob: String, room: ChatRoom = defaultRooms[0]) {
        val trimmedName = name.trim().ifBlank { "AuraListener" }
        val trimmedDob = dob.trim().ifBlank { "01/01/2000" }

        val profile = RoomProfile(
            name = trimmedName,
            dob = trimmedDob
        )
        _currentProfile.value = profile
        _currentRoom.value = room
        _groupPlaylist.value = emptyList()

        // Ensure room is in available list
        if (_availableRooms.value.none { it.id == room.id }) {
            _availableRooms.value = listOf(room) + _availableRooms.value
        }

        val welcomeMsg = ChatMessage(
            id = "sys_welcome_${System.currentTimeMillis()}",
            senderId = "system",
            senderName = "Aura Room Bot",
            text = "🎉 Welcome $trimmedName to #${room.name}! Room ID: ${room.id}. Anyone in this group can add songs to the live playlist and chat in real time.",
            reactions = mapOf("✨" to 1),
            isFromMe = false
        )
        _messages.value = listOf(welcomeMsg)

        startLiveSync()
    }

    fun switchRoom(room: ChatRoom) {
        _currentRoom.value = room
        _groupPlaylist.value = emptyList()
        if (_availableRooms.value.none { it.id == room.id }) {
            _availableRooms.value = listOf(room) + _availableRooms.value
        }
        _messages.value = emptyList()
        startLiveSync()
    }

    fun leaveRoom() {
        syncJob?.cancel()
        _currentProfile.value = null
        _messages.value = emptyList()
        _groupPlaylist.value = emptyList()
    }

    fun addReaction(messageId: String, emoji: String) {
        val currentList = _messages.value.toMutableList()
        val index = currentList.indexOfFirst { it.id == messageId }
        if (index != -1) {
            val msg = currentList[index]
            val currentReactions = msg.reactions.toMutableMap()
            val currentCount = currentReactions[emoji] ?: 0
            currentReactions[emoji] = currentCount + 1
            currentList[index] = msg.copy(reactions = currentReactions)
            _messages.value = currentList

            scope.launch(Dispatchers.IO) {
                broadcastMessage(currentList[index])
            }
        }
    }

    // -------------------------------------------------------------
    // Real-Time Group Collaborative Playlist
    // -------------------------------------------------------------
    fun addSongToGroupPlaylist(song: Song) {
        val profile = _currentProfile.value ?: return

        // 1. Add locally
        val current = _groupPlaylist.value.toMutableList()
        if (current.none { it.song.id == song.id }) {
            current.add(GroupPlaylistItem(song, profile.name))
            _groupPlaylist.value = current
        }

        // 2. Announce in room chat with song card
        val announceMsg = ChatMessage(
            id = "msg_queue_${System.currentTimeMillis()}",
            senderId = profile.userId,
            senderName = profile.name,
            text = "🎶 Added to Group Playlist: ${song.title} - ${song.artist}",
            timestamp = System.currentTimeMillis(),
            sharedSong = song,
            reactions = mapOf("🔥" to 1),
            isFromMe = true
        )
        _messages.value = _messages.value + announceMsg

        // 3. Broadcast real-time playlist packet
        val packet = GroupSyncPacket(
            type = "PLAYLIST_ADD",
            roomId = _currentRoom.value.id,
            senderId = profile.userId,
            senderName = profile.name,
            message = announceMsg,
            song = song,
            playlist = _groupPlaylist.value.map { it.song }
        )

        scope.launch(Dispatchers.IO) {
            broadcastRaw(gson.toJson(packet))
        }
    }

    fun removeSongFromGroupPlaylist(songId: String) {
        val current = _groupPlaylist.value.toMutableList()
        current.removeAll { it.song.id == songId }
        _groupPlaylist.value = current
    }

    fun syncPlaybackToGroup(song: Song, isPlaying: Boolean = true, positionSec: Double = 0.0) {
        val profile = _currentProfile.value ?: return
        val packet = GroupSyncPacket(
            type = "SYNC_PLAYBACK",
            roomId = _currentRoom.value.id,
            senderId = profile.userId,
            senderName = profile.name,
            song = song,
            action = if (isPlaying) "PLAY" else "PAUSE",
            positionSec = positionSec
        )
        scope.launch(Dispatchers.IO) {
            broadcastRaw(gson.toJson(packet))
        }
    }

    // -------------------------------------------------------------
    // Chat Message Broadcasting
    // -------------------------------------------------------------
    fun sendMessage(text: String, sharedSong: Song? = null) {
        if (text.isBlank() && sharedSong == null) return
        val profile = _currentProfile.value ?: return

        val newMsg = ChatMessage(
            id = "msg_${System.currentTimeMillis()}_${(100..999).random()}",
            senderId = profile.userId,
            senderName = profile.name,
            text = text,
            timestamp = System.currentTimeMillis(),
            sharedSong = sharedSong,
            reactions = emptyMap(),
            isFromMe = true
        )

        _messages.value = _messages.value + newMsg

        // If a song was shared in the chat, automatically add it to group playlist!
        if (sharedSong != null) {
            val currentList = _groupPlaylist.value.toMutableList()
            if (currentList.none { it.song.id == sharedSong.id }) {
                currentList.add(GroupPlaylistItem(sharedSong, profile.name))
                _groupPlaylist.value = currentList
            }
        }

        val packet = GroupSyncPacket(
            type = "CHAT_MSG",
            roomId = _currentRoom.value.id,
            senderId = profile.userId,
            senderName = profile.name,
            message = newMsg,
            song = sharedSong
        )

        scope.launch(Dispatchers.IO) {
            broadcastRaw(gson.toJson(packet))
        }
    }

    fun normalizedTopic(roomId: String): String {
        val clean = roomId.trim().lowercase()
            .replace("-", "_")
            .replace(" ", "_")
        return "aura_music_$clean"
    }

    // -------------------------------------------------------------
    // Real-Time Persistent Streaming & Sync Engine (Zero Rate Limit)
    // -------------------------------------------------------------
    private fun startLiveSync() {
        syncJob?.cancel()
        syncJob = scope.launch(Dispatchers.IO) {
            val streamClient = httpClient.newBuilder()
                .readTimeout(0, TimeUnit.MILLISECONDS) // Persistent streaming connection
                .build()

            while (isActive) {
                val profile = _currentProfile.value ?: break
                val roomId = _currentRoom.value.id
                val topic = normalizedTopic(roomId)
                val url = "https://ntfy.sh/$topic/json?since=4h"

                try {
                    val request = Request.Builder()
                        .url(url)
                        .header("Accept", "application/x-ndjson")
                        .build()

                    streamClient.newCall(request).execute().use { response ->
                        if (response.isSuccessful) {
                            val source = response.body?.source() ?: return@use
                            while (!source.exhausted() && isActive) {
                                val line = source.readUtf8Line() ?: break
                                if (line.isNotBlank()) {
                                    handleIncomingStreamLine(line, profile)
                                }
                            }
                        }
                    }
                } catch (_: Exception) {}

                // Auto-reconnect backoff
                delay(1500)
            }
        }
    }

    private suspend fun handleIncomingStreamLine(line: String, profile: RoomProfile) {
        try {
            val eventObj = gson.fromJson(line, JsonObject::class.java)
            val messageContent = eventObj.get("message")?.asString ?: return

            // 1. Try parsing as GroupSyncPacket
            val packet = try {
                gson.fromJson(messageContent, GroupSyncPacket::class.java)
            } catch (_: Exception) { null }

            if (packet != null && !packet.type.isNullOrBlank()) {
                when (packet.type) {
                    "CHAT_MSG" -> {
                        packet.message?.let { rawMsg ->
                            val isMe = (rawMsg.senderId == profile.userId)
                            insertOrUpdateMessage(rawMsg.copy(isFromMe = isMe))
                        }
                        packet.song?.let { song ->
                            addSongToLocalPlaylist(song, packet.senderName)
                        }
                    }
                    "PLAYLIST_ADD" -> {
                        packet.song?.let { song ->
                            addSongToLocalPlaylist(song, packet.senderName)
                        }
                        packet.message?.let { rawMsg ->
                            val isMe = (rawMsg.senderId == profile.userId)
                            insertOrUpdateMessage(rawMsg.copy(isFromMe = isMe))
                        }
                    }
                    "PLAYLIST_CLEAR" -> {
                        withContext(Dispatchers.Main) {
                            _groupPlaylist.value = emptyList()
                        }
                    }
                    "SYNC_PLAYBACK" -> {
                        if (packet.senderId != profile.userId && packet.song != null) {
                            withContext(Dispatchers.Main) {
                                PlaybackManager.playSong(packet.song)
                                if (packet.positionSec > 0) {
                                    PlaybackManager.seekTo((packet.positionSec * 1000).toLong())
                                }
                            }
                        }
                    }
                }
                return
            }

            // 2. Fallback parsing as direct ChatMessage
            val msg = gson.fromJson(messageContent, ChatMessage::class.java)
            if (msg != null && !msg.id.isNullOrBlank()) {
                val correctedTimestamp = if (msg.timestamp in 1..100_000_000_000L) {
                    msg.timestamp * 1000L
                } else {
                    msg.timestamp
                }
                val isMe = (msg.senderId == profile.userId)
                insertOrUpdateMessage(msg.copy(timestamp = correctedTimestamp, isFromMe = isMe))

                msg.sharedSong?.let { song ->
                    addSongToLocalPlaylist(song, msg.senderName)
                }
            }
        } catch (_: Exception) {}
    }

    private suspend fun addSongToLocalPlaylist(song: Song, addedBy: String) = withContext(Dispatchers.Main) {
        val current = _groupPlaylist.value.toMutableList()
        if (current.none { it.song.id == song.id }) {
            current.add(GroupPlaylistItem(song, addedBy))
            _groupPlaylist.value = current
        }
    }

    private suspend fun insertOrUpdateMessage(msg: ChatMessage) = withContext(Dispatchers.Main) {
        val currentMap = _messages.value.associateBy { it.id }.toMutableMap()
        val existing = currentMap[msg.id]
        if (existing != null) {
            val mergedReactions = existing.reactions.toMutableMap()
            for ((emoji, count) in msg.reactions) {
                mergedReactions[emoji] = maxOf(mergedReactions[emoji] ?: 0, count)
            }
            currentMap[msg.id] = msg.copy(reactions = mergedReactions)
        } else {
            currentMap[msg.id] = msg
        }
        _messages.value = currentMap.values.sortedBy { it.timestamp }
    }

    private suspend fun broadcastRaw(jsonPayload: String) = withContext(Dispatchers.IO) {
        val roomId = _currentRoom.value.id
        val topic = normalizedTopic(roomId)
        try {
            val relayBody = jsonPayload.toRequestBody("application/json".toMediaType())
            val relayReq = Request.Builder()
                .url("https://ntfy.sh/$topic")
                .post(relayBody)
                .build()
            httpClient.newCall(relayReq).execute().close()
        } catch (_: Exception) {}
    }

    private suspend fun broadcastMessage(message: ChatMessage) = withContext(Dispatchers.IO) {
        val packet = GroupSyncPacket(
            type = "CHAT_MSG",
            roomId = _currentRoom.value.id,
            senderId = message.senderId,
            senderName = message.senderName,
            message = message,
            song = message.sharedSong
        )
        broadcastRaw(gson.toJson(packet))
    }
}
