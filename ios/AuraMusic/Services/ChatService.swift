import Foundation
import Combine

public final class ChatService: ObservableObject {
    public static let shared = ChatService()

    public let popularEmojis = ["❤️", "🔥", "🎧", "👏", "😂", "😮", "🚀", "✨", "🎵"]

    public let defaultRooms: [ChatRoom] = [
        ChatRoom(id: "room_global", name: "Global Music Lounge", description: "Live music discussions & real-time song sharing", activeListeners: 18),
        ChatRoom(id: "room_late_night", name: "Late Night Vibes", description: "Lo-fi beats, synthwave, and midnight conversations", activeListeners: 9),
        ChatRoom(id: "room_edm", name: "Bass & Electronic", description: "Fast tempos, heavy drops, and hype tracks", activeListeners: 14)
    ]

    @Published public var availableRooms: [ChatRoom] = []
    @Published public var currentProfile: RoomProfile?
    @Published public var currentRoom: ChatRoom
    @Published public var messages: [ChatMessage] = []

    // Real-Time Shared Group Playlist
    @Published public var groupPlaylist: [GroupPlaylistItem] = []

    private var streamTask: Task<Void, Never>?

    private init() {
        self.availableRooms = defaultRooms
        let initialRoom = defaultRooms[0]
        self.currentRoom = initialRoom
        let defaultHandle = "Listener_\(Int.random(in: 1000...9999))"
        joinRoom(name: defaultHandle, dob: "01/01/2000", room: initialRoom)
    }

    public func updateProfileName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dob = currentProfile?.dob ?? "01/01/2000"
        self.currentProfile = RoomProfile(name: trimmed, dob: dob)
    }

    public static func normalizedTopic(for roomId: String) -> String {
        let clean = roomId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return "aura_music_\(clean)"
    }

    // -------------------------------------------------------------
    // Room Creation & Joining (Cross-Platform with Android)
    // -------------------------------------------------------------
    public func createRoom(name: String, description: String = "") -> ChatRoom {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Aura Lounge" : name
        let randomNum = Int.random(in: 1000...9999)
        let uniqueId = "AURA-\(randomNum)"
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Live Group • Code: \(uniqueId)" : description

        let newRoom = ChatRoom(
            id: uniqueId,
            name: trimmed,
            description: desc,
            activeListeners: 1
        )

        if !availableRooms.contains(where: { $0.id == newRoom.id }) {
            availableRooms.insert(newRoom, at: 0)
        }
        return newRoom
    }

    public func joinRoomById(name: String, dob: String, roomId: String) -> Bool {
        let cleanId = roomId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanId.isEmpty else { return false }

        let existing = availableRooms.first { $0.id.caseInsensitiveCompare(cleanId) == .orderedSame }
        let target = existing ?? ChatRoom(
            id: cleanId,
            name: cleanId,
            description: "Group Room • ID: \(cleanId)",
            activeListeners: 1
        )

        joinRoom(name: name, dob: dob, room: target)
        return true
    }

    public func createAndJoinRoom(userName: String, userDob: String, roomName: String, description: String = "") -> ChatRoom {
        let room = createRoom(name: roomName, description: description)
        joinRoom(name: userName, dob: userDob, room: room)
        return room
    }

    public func joinRoom(name: String, dob: String, room: ChatRoom? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "AuraListener" : name
        let trimmedDob = dob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "01/01/2000" : dob

        let selected = room ?? defaultRooms[0]
        self.currentProfile = RoomProfile(name: trimmedName, dob: trimmedDob)
        self.currentRoom = selected
        self.groupPlaylist = []

        if !availableRooms.contains(where: { $0.id == selected.id }) {
            availableRooms.insert(selected, at: 0)
        }

        let welcome = ChatMessage(
            id: "sys_welcome_\(Int(Date().timeIntervalSince1970 * 1000))",
            senderId: "system",
            senderName: "Aura Room Bot",
            text: "🎉 Welcome \(trimmedName) to #\(selected.name)! Room Code: \(selected.id). Anyone in this group can add songs to the live playlist and chat in real time.",
            reactions: ["✨": 1],
            isFromMe: false
        )
        self.messages = [welcome]

        startLiveSync()
    }

    public func switchRoom(_ room: ChatRoom) {
        self.currentRoom = room
        self.groupPlaylist = []
        if !availableRooms.contains(where: { $0.id == room.id }) {
            availableRooms.insert(room, at: 0)
        }
        self.messages = []
        startLiveSync()
    }

    public func leaveRoom() {
        streamTask?.cancel()
        streamTask = nil
        currentProfile = nil
        messages = []
        groupPlaylist = []
    }

    // -------------------------------------------------------------
    // Real-Time Messaging & Reactions
    // -------------------------------------------------------------
    public func addReaction(to messageId: String, emoji: String) {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        var msg = messages[idx]
        msg.reactions[emoji, default: 0] += 1
        messages[idx] = msg

        broadcastMessage(msg)
    }

    // -------------------------------------------------------------
    // Group Collaborative Playlist Operations
    // -------------------------------------------------------------
    public func addSongToGroupPlaylist(_ song: Song) {
        guard let profile = currentProfile else { return }

        // 1. Add locally if not present
        if !groupPlaylist.contains(where: { $0.song.id == song.id }) {
            groupPlaylist.append(GroupPlaylistItem(song: song, addedBy: profile.name))
        }

        // 2. Announce in room chat with song card
        let announceMsg = ChatMessage(
            id: "msg_queue_\(Int(Date().timeIntervalSince1970 * 1000))",
            senderId: profile.userId,
            senderName: profile.name,
            text: "🎶 Added to Group Playlist: \(song.title) - \(song.artist)",
            timestamp: Date(),
            sharedSong: song,
            reactions: ["🔥": 1],
            isFromMe: true
        )
        messages.append(announceMsg)

        // 3. Broadcast real-time playlist packet
        let packet = GroupSyncPacket(
            type: "PLAYLIST_ADD",
            roomId: currentRoom.id,
            senderId: profile.userId,
            senderName: profile.name,
            message: announceMsg,
            song: song,
            playlist: groupPlaylist.map { $0.song }
        )

        broadcastPacket(packet)
    }

    public func syncPlaybackToGroup(song: Song, isPlaying: Bool = true, positionSec: Double = 0.0) {
        guard let profile = currentProfile else { return }
        let packet = GroupSyncPacket(
            type: "SYNC_PLAYBACK",
            roomId: currentRoom.id,
            senderId: profile.userId,
            senderName: profile.name,
            song: song,
            action: isPlaying ? "PLAY" : "PAUSE",
            positionSec: positionSec
        )
        broadcastPacket(packet)
    }

    public func sendMessage(text: String, sharedSong: Song? = nil) {
        guard let profile = currentProfile else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || sharedSong != nil else { return }

        let newMsg = ChatMessage(
            id: "msg_\(Int(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 100...999))",
            senderId: profile.userId,
            senderName: profile.name,
            text: trimmed,
            timestamp: Date(),
            sharedSong: sharedSong,
            reactions: [:],
            isFromMe: true
        )

        messages.append(newMsg)

        // If song is shared in chat, automatically append to group playlist
        if let song = sharedSong {
            if !groupPlaylist.contains(where: { $0.song.id == song.id }) {
                groupPlaylist.append(GroupPlaylistItem(song: song, addedBy: profile.name))
            }
        }

        let packet = GroupSyncPacket(
            type: "CHAT_MSG",
            roomId: currentRoom.id,
            senderId: profile.userId,
            senderName: profile.name,
            message: newMsg,
            song: sharedSong
        )

        broadcastPacket(packet)
    }

    // -------------------------------------------------------------
    // Real-Time Streaming SSE Receiver (Zero Rate Limit & Instant Push)
    // -------------------------------------------------------------
    private func startLiveSync() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, let profile = self.currentProfile else { break }
                let topic = Self.normalizedTopic(for: self.currentRoom.id)
                guard let streamUrl = URL(string: "https://ntfy.sh/\(topic)/json?since=4h") else { break }

                do {
                    var request = URLRequest(url: streamUrl)
                    request.timeoutInterval = 3600 // Keep alive
                    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")

                    if #available(iOS 15.0, *) {
                        let (bytes, response) = try await URLSession.shared.bytes(for: request)
                        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                            try await Task.sleep(nanoseconds: 2_000_000_000)
                            continue
                        }

                        for try await line in bytes.lines {
                            guard !Task.isCancelled else { break }
                            if !line.isEmpty {
                                await self.handleIncomingLine(line, profile: profile)
                            }
                        }
                    } else {
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                } catch {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
        }
    }

    @MainActor
    private func handleIncomingLine(_ line: String, profile: RoomProfile) {
        guard let lineData = line.data(using: .utf8),
              let eventJson = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let msgString = eventJson["message"] as? String,
              let msgData = msgString.data(using: .utf8) else { return }

        // 1. Try decoding GroupSyncPacket
        if let packet = try? JSONDecoder().decode(GroupSyncPacket.self, from: msgData) {
            switch packet.type {
            case "CHAT_MSG":
                if let rawMsg = packet.message {
                    var copy = rawMsg
                    copy.isFromMe = (rawMsg.senderId == profile.userId)
                    insertOrUpdateMessage(copy)
                }
                if let song = packet.song {
                    addToLocalPlaylist(song, addedBy: packet.senderName)
                }
            case "PLAYLIST_ADD":
                if let song = packet.song {
                    addToLocalPlaylist(song, addedBy: packet.senderName)
                }
                if let rawMsg = packet.message {
                    var copy = rawMsg
                    copy.isFromMe = (rawMsg.senderId == profile.userId)
                    insertOrUpdateMessage(copy)
                }
            case "SYNC_PLAYBACK":
                if packet.senderId != profile.userId, let song = packet.song {
                    AudioPlayerService.shared.playSong(song)
                    if let sec = packet.positionSec, sec > 0 {
                        AudioPlayerService.shared.seek(to: sec)
                    }
                }
            default:
                break
            }
            return
        }

        // 2. Fallback decoding direct ChatMessage
        if let parsed = try? JSONDecoder().decode(ChatMessage.self, from: msgData) {
            var copy = parsed
            copy.isFromMe = (parsed.senderId == profile.userId)
            insertOrUpdateMessage(copy)

            if let song = parsed.sharedSong {
                addToLocalPlaylist(song, addedBy: parsed.senderName)
            }
        }
    }

    @MainActor
    private func addToLocalPlaylist(_ song: Song, addedBy: String) {
        if !groupPlaylist.contains(where: { $0.song.id == song.id }) {
            groupPlaylist.append(GroupPlaylistItem(song: song, addedBy: addedBy))
        }
    }

    @MainActor
    private func insertOrUpdateMessage(_ msg: ChatMessage) {
        var map = Dictionary(uniqueKeysWithValues: self.messages.map { ($0.id, $0) })
        if let existing = map[msg.id] {
            var merged = existing.reactions
            for (emoji, count) in msg.reactions {
                merged[emoji] = max(merged[emoji] ?? 0, count)
            }
            var updated = msg
            updated.reactions = merged
            map[msg.id] = updated
        } else {
            map[msg.id] = msg
        }
        self.messages = map.values.sorted(by: { $0.timestamp < $1.timestamp })
    }

    private func broadcastPacket(_ packet: GroupSyncPacket) {
        guard let payloadData = try? JSONEncoder().encode(packet) else { return }
        broadcastRaw(payloadData)
    }

    private func broadcastMessage(_ message: ChatMessage) {
        let packet = GroupSyncPacket(
            type: "CHAT_MSG",
            roomId: currentRoom.id,
            senderId: message.senderId,
            senderName: message.senderName,
            message: message,
            song: message.sharedSong
        )
        broadcastPacket(packet)
    }

    private func broadcastRaw(_ data: Data) {
        let topic = Self.normalizedTopic(for: currentRoom.id)
        guard let relayUrl = URL(string: "https://ntfy.sh/\(topic)") else { return }
        var req = URLRequest(url: relayUrl)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        URLSession.shared.dataTask(with: req).resume()
    }
}
