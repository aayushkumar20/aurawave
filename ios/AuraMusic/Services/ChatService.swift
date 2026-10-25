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

    private var syncTimer: Timer?

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

        if !availableRooms.contains(where: { $0.id == selected.id }) {
            availableRooms.insert(selected, at: 0)
        }

        let welcome = ChatMessage(
            id: "sys_welcome_\(Int(Date().timeIntervalSince1970 * 1000))",
            senderId: "system",
            senderName: "Aura Room Bot",
            text: "🎉 Welcome \(trimmedName) to #\(selected.name)! Room Code: \(selected.id). Chat, share music live, and react in real time.",
            reactions: ["✨": 1],
            isFromMe: false
        )
        self.messages = [welcome]

        startLiveSync()
    }

    public func switchRoom(_ room: ChatRoom) {
        self.currentRoom = room
        if !availableRooms.contains(where: { $0.id == room.id }) {
            availableRooms.insert(room, at: 0)
        }
        self.messages = []
        startLiveSync()
    }

    public func leaveRoom() {
        syncTimer?.invalidate()
        syncTimer = nil
        currentProfile = nil
        messages = []
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
        broadcastMessage(newMsg)
    }

    private func startLiveSync() {
        syncTimer?.invalidate()
        // Immediate fetch upon joining
        pollRoomUpdates()
        // Fast 1.5s real-time poll
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.pollRoomUpdates()
        }
    }

    private func broadcastMessage(_ message: ChatMessage) {
        let topic = Self.normalizedTopic(for: currentRoom.id)
        guard let payloadData = try? JSONEncoder().encode(message) else { return }

        // Fast realtime pubsub relay
        guard let relayUrl = URL(string: "https://ntfy.sh/\(topic)") else { return }
        var req = URLRequest(url: relayUrl)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payloadData
        URLSession.shared.dataTask(with: req).resume()
    }

    private func pollRoomUpdates() {
        guard let profile = currentProfile else { return }
        let topic = Self.normalizedTopic(for: currentRoom.id)
        guard let url = URL(string: "https://ntfy.sh/\(topic)/json?poll=1&since=12h") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data,
                  let stringData = String(data: data, encoding: .utf8) else { return }

            let lines = stringData.components(separatedBy: "\n")
            var newMessages: [ChatMessage] = []

            for line in lines where !line.isEmpty {
                guard let lineData = line.data(using: .utf8),
                      let eventJson = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let msgString = eventJson["message"] as? String,
                      let msgData = msgString.data(using: .utf8),
                      let parsed = try? JSONDecoder().decode(ChatMessage.self, from: msgData) else { continue }

                var copy = parsed
                copy.isFromMe = (parsed.senderId == profile.userId)
                newMessages.append(copy)
            }

            if !newMessages.isEmpty {
                DispatchQueue.main.async {
                    var map = Dictionary(uniqueKeysWithValues: self.messages.map { ($0.id, $0) })
                    for m in newMessages {
                        // Merge or update reaction counts
                        if let existing = map[m.id] {
                            var mergedReactions = existing.reactions
                            for (emoji, count) in m.reactions {
                                mergedReactions[emoji] = max(mergedReactions[emoji] ?? 0, count)
                            }
                            var updated = m
                            updated.reactions = mergedReactions
                            map[m.id] = updated
                        } else {
                            map[m.id] = m
                        }
                    }
                    self.messages = map.values.sorted(by: { $0.timestamp < $1.timestamp })
                }
            }
        }.resume()
    }
}
