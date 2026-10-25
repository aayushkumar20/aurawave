package com.auramusic.app.data.repository

import com.auramusic.app.data.models.ChatMessage
import com.auramusic.app.data.models.ChatRoom
import com.auramusic.app.data.models.RoomProfile
import com.auramusic.app.data.models.Song
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
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(5, TimeUnit.SECONDS)
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

        // Ensure room is in available list
        if (_availableRooms.value.none { it.id == room.id }) {
            _availableRooms.value = listOf(room) + _availableRooms.value
        }

        val welcomeMsg = ChatMessage(
            id = "sys_welcome_${System.currentTimeMillis()}",
            senderId = "system",
            senderName = "Aura Room Bot",
            text = "🎉 Welcome $trimmedName to #${room.name}! Room ID: ${room.id}. Share songs live, chat, or invite friends with this Room ID.",
            reactions = mapOf("✨" to 1),
            isFromMe = false
        )
        _messages.value = listOf(welcomeMsg)

        startLiveSync()
    }

    fun switchRoom(room: ChatRoom) {
        _currentRoom.value = room
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

    fun sendMessage(text: String, sharedSong: Song? = null) {
        if (text.isBlank() && sharedSong == null) return
        val profile = _currentProfile.value ?: return

        val newMsg = ChatMessage(
            id = "msg_${System.currentTimeMillis()}",
            senderId = profile.userId,
            senderName = profile.name,
            text = text,
            timestamp = System.currentTimeMillis(),
            sharedSong = sharedSong,
            reactions = emptyMap(),
            isFromMe = true
        )

        _messages.value = _messages.value + newMsg

        scope.launch(Dispatchers.IO) {
            broadcastMessage(newMsg)
        }
    }

    fun normalizedTopic(roomId: String): String {
        val clean = roomId.trim().lowercase()
            .replace("-", "_")
            .replace(" ", "_")
        return "aura_music_$clean"
    }

    private fun startLiveSync() {
        syncJob?.cancel()
        syncJob = scope.launch(Dispatchers.IO) {
            // Immediate sync upon entering
            pollRoomUpdates()
            while (isActive) {
                delay(1500)
                pollRoomUpdates()
            }
        }
    }

    private suspend fun broadcastMessage(message: ChatMessage) = withContext(Dispatchers.IO) {
        val roomId = _currentRoom.value.id
        val topic = normalizedTopic(roomId)
        val jsonPayload = gson.toJson(message)

        // Broadcast to instantaneous real-time pubsub relay
        try {
            val relayBody = jsonPayload.toRequestBody("application/json".toMediaType())
            val relayReq = Request.Builder()
                .url("https://ntfy.sh/$topic")
                .post(relayBody)
                .build()
            httpClient.newCall(relayReq).execute().close()
        } catch (_: Exception) {}
    }

    private suspend fun pollRoomUpdates() = withContext(Dispatchers.IO) {
        val roomId = _currentRoom.value.id
        val profile = _currentProfile.value ?: return@withContext
        val topic = normalizedTopic(roomId)

        // Poll from live relay with 12h history window
        try {
            val url = "https://ntfy.sh/$topic/json?poll=1&since=12h"
            val request = Request.Builder().url(url).build()

            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val body = response.body?.string() ?: return@use
                    val lines = body.split("\n")
                    val fetched = mutableListOf<ChatMessage>()

                    for (line in lines) {
                        if (line.isBlank()) continue
                        try {
                            val eventObj = gson.fromJson(line, JsonObject::class.java)
                            val messageContent = eventObj.get("message")?.asString ?: continue
                            val msg = gson.fromJson(messageContent, ChatMessage::class.java)
                            if (msg != null) {
                                val correctedTimestamp = if (msg.timestamp in 1..100_000_000_000L) {
                                    msg.timestamp * 1000L
                                } else {
                                    msg.timestamp
                                }
                                val isMe = (msg.senderId == profile.userId)
                                fetched.add(msg.copy(timestamp = correctedTimestamp, isFromMe = isMe))
                            }
                        } catch (_: Exception) {}
                    }

                    if (fetched.isNotEmpty()) {
                        withContext(Dispatchers.Main) {
                            val currentMap = _messages.value.associateBy { it.id }.toMutableMap()
                            for (f in fetched) {
                                val existing = currentMap[f.id]
                                if (existing != null) {
                                    val mergedReactions = existing.reactions.toMutableMap()
                                    for ((emoji, count) in f.reactions) {
                                        mergedReactions[emoji] = maxOf(mergedReactions[emoji] ?: 0, count)
                                    }
                                    currentMap[f.id] = f.copy(reactions = mergedReactions)
                                } else {
                                    currentMap[f.id] = f
                                }
                            }
                            _messages.value = currentMap.values.sortedBy { it.timestamp }
                        }
                    }
                }
            }
        } catch (_: Exception) {}
    }
}
