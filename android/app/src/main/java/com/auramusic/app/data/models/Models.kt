package com.auramusic.app.data.models

data class Song(
    val id: String,
    val title: String,
    val artist: String,
    val album: String = "YouTube Music Single",
    val durationText: String = "3:30",
    val durationMs: Long = 210000L,
    val durationSeconds: Double = 210.0,
    val thumbnailUrl: String,
    val streamUrl: String? = null,
    val isFavorite: Boolean = false
)

data class Playlist(
    val id: String,
    val name: String,
    val description: String = "",
    val coverUrl: String,
    val songs: List<Song> = emptyList()
)

data class ChatUser(
    val id: String,
    val name: String,
    val avatarUrl: String,
    val status: String = "Online",
    val isOnline: Boolean = true
)

data class RoomProfile(
    val name: String,
    val dob: String,
    val userId: String = "user_${name.lowercase().replace(" ", "_")}_${dob.replace("/", "").replace("-", "")}",
    val avatarUrl: String = "https://api.dicebear.com/7.x/bottts/png?seed=$name"
)

data class ChatRoom(
    val id: String,
    val name: String,
    val description: String,
    val activeListeners: Int = 1
)

data class ChatMessage(
    val id: String,
    val senderId: String,
    val senderName: String,
    val text: String,
    val timestamp: Long = System.currentTimeMillis(),
    val sharedSong: Song? = null,
    val reactions: Map<String, Int> = emptyMap(),
    val isFromMe: Boolean = false
)

enum class RepeatMode {
    OFF, ALL, ONE
}
