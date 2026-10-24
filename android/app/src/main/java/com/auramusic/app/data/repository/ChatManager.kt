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

    private val _currentProfile = MutableStateFlow<RoomProfile?>(null)
    val currentProfile: StateFlow<RoomProfile?> = _currentProfile.asStateFlow()

    private val _currentRoom = MutableStateFlow(defaultRooms[0])
    val currentRoom: StateFlow<ChatRoom> = _currentRoom.asStateFlow()

    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()

    fun joinRoom(name: String, dob: String, room: ChatRoom = defaultRooms[0]) {
        val trimmedName = name.trim().ifBlank { "AuraListener" }
        val trimmedDob = dob.trim().ifBlank { "01/01/2000" }

        val profile = RoomProfile(
            name = trimmedName,
            dob = trimmedDob
        )
        _currentProfile.value = profile
        _currentRoom.value = room

        val welcomeMsg = ChatMessage(
            id = "sys_welcome_${System.currentTimeMillis()}",
            senderId = "system",
            senderName = "Aura Room Bot",
            text = "🎉 Welcome $trimmedName to #${room.name}! Share any YouTube Music song live, chat, or react with emojis.",
            reactions = mapOf("✨" to 1),
            isFromMe = false
        )
        _messages.value = listOf(welcomeMsg)

        startLiveSync()
    }

    fun switchRoom(room: ChatRoom) {
        _currentRoom.value = room
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

    private fun startLiveSync() {
        syncJob?.cancel()
        syncJob = scope.launch(Dispatchers.IO) {
            while (isActive) {
                pollRoomUpdates()
                delay(2500)
            }
        }
    }

    private suspend fun broadcastMessage(message: ChatMessage) = withContext(Dispatchers.IO) {
        val roomId = _currentRoom.value.id
        val jsonPayload = gson.toJson(message)

        // 1. Broadcast to Firebase Realtime Database
        try {
            val reqBody = jsonPayload.toRequestBody("application/json".toMediaType())
            val fbReq = Request.Builder()
                .url("$firebaseDatabaseUrl/rooms/$roomId/messages/${message.id}.json")
                .put(reqBody)
                .build()
            httpClient.newCall(fbReq).execute().close()
        } catch (_: Exception) {}

        // 2. Broadcast to instantaneous real-time pubsub relay
        try {
            val relayBody = jsonPayload.toRequestBody("application/json".toMediaType())
            val relayReq = Request.Builder()
                .url("https://ntfy.sh/aura_music_${roomId}")
                .post(relayBody)
                .build()
            httpClient.newCall(relayReq).execute().close()
        } catch (_: Exception) {}
    }

    private suspend fun pollRoomUpdates() = withContext(Dispatchers.IO) {
        val roomId = _currentRoom.value.id
        val profile = _currentProfile.value ?: return@withContext

        // Poll from live relay
        try {
            val url = "https://ntfy.sh/aura_music_${roomId}/json?poll=1&since=1m"
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
                            if (msg != null && msg.senderId != profile.userId) {
                                fetched.add(msg.copy(isFromMe = false))
                            }
                        } catch (_: Exception) {}
                    }

                    if (fetched.isNotEmpty()) {
                        withContext(Dispatchers.Main) {
                            val currentMap = _messages.value.associateBy { it.id }.toMutableMap()
                            for (f in fetched) {
                                currentMap[f.id] = f
                            }
                            _messages.value = currentMap.values.sortedBy { it.timestamp }
                        }
                    }
                }
            }
        } catch (_: Exception) {}
    }
}
