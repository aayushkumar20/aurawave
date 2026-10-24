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

object ChatManager {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private val httpClient = OkHttpClient()
    private val gson = Gson()
    private var syncJob: Job? = null

    var firebaseDatabaseUrl = "https://aura-music-app-default-rtdb.firebaseio.com"

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

        // Post welcome message into local room
        val welcomeMsg = ChatMessage(
            id = "sys_welcome_${System.currentTimeMillis()}",
            senderId = "system",
            senderName = "Aura Room Bot",
            text = "🎉 Welcome $trimmedName to #${room.name}! Share any YouTube Music song live, chat, or react with emojis.",
            reactions = mapOf("✨" to 1),
            isFromMe = false
        )
        _messages.value = listOf(welcomeMsg)

        // Start real-time Firebase sync
        startFirebaseLiveSync()
    }

    fun switchRoom(room: ChatRoom) {
        _currentRoom.value = room
        _messages.value = emptyList()
        startFirebaseLiveSync()
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

            // Sync reaction to Firebase
            scope.launch(Dispatchers.IO) {
                syncMessageToFirebase(currentList[index])
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

        // Push to Firebase Realtime Database
        scope.launch(Dispatchers.IO) {
            syncMessageToFirebase(newMsg)
        }
    }

    private fun startFirebaseLiveSync() {
        syncJob?.cancel()
        syncJob = scope.launch(Dispatchers.IO) {
            while (isActive) {
                fetchMessagesFromFirebase()
                delay(3000) // Poll Firebase Realtime DB every 3s
            }
        }
    }

    private suspend fun fetchMessagesFromFirebase() = withContext(Dispatchers.IO) {
        val roomId = _currentRoom.value.id
        val profile = _currentProfile.value ?: return@withContext

        try {
            val url = "$firebaseDatabaseUrl/rooms/$roomId/messages.json"
            val request = Request.Builder().url(url).build()

            httpClient.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val body = response.body?.string()
                    if (!body.isNullOrBlank() && body != "null") {
                        val json = gson.fromJson(body, JsonObject::class.java)
                        val fetchedList = mutableListOf<ChatMessage>()

                        for (key in json.keySet()) {
                            val msgObj = json.getAsJsonObject(key)
                            val id = msgObj.get("id")?.asString ?: key
                            val senderId = msgObj.get("senderId")?.asString ?: ""
                            val senderName = msgObj.get("senderName")?.asString ?: "Unknown"
                            val text = msgObj.get("text")?.asString ?: ""
                            val timestamp = msgObj.get("timestamp")?.asLong ?: System.currentTimeMillis()
                            val isMe = senderId == profile.userId

                            fetchedList.add(
                                ChatMessage(
                                    id = id,
                                    senderId = senderId,
                                    senderName = senderName,
                                    text = text,
                                    timestamp = timestamp,
                                    sharedSong = null,
                                    reactions = emptyMap(),
                                    isFromMe = isMe
                                )
                            )
                        }

                        if (fetchedList.isNotEmpty()) {
                            withContext(Dispatchers.Main) {
                                val currentMap = _messages.value.associateBy { it.id }.toMutableMap()
                                for (item in fetchedList) {
                                    if (!currentMap.containsKey(item.id)) {
                                        currentMap[item.id] = item
                                    }
                                }
                                _messages.value = currentMap.values.sortedBy { it.timestamp }
                            }
                        }
                    }
                }
            }
        } catch (_: Exception) {}
    }

    private suspend fun syncMessageToFirebase(message: ChatMessage) = withContext(Dispatchers.IO) {
        val roomId = _currentRoom.value.id
        try {
            val jsonPayload = gson.toJson(message)
            val requestBody = jsonPayload.toRequestBody("application/json; charset=utf-8".toMediaType())
            val url = "$firebaseDatabaseUrl/rooms/$roomId/messages/${message.id}.json"

            val request = Request.Builder()
                .url(url)
                .put(requestBody)
                .build()

            httpClient.newCall(request).execute().close()
        } catch (_: Exception) {}
    }
}
