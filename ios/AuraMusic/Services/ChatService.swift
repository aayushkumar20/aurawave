import Foundation
import Combine

public final class ChatService: ObservableObject {
    public static let shared = ChatService()

    public var firebaseDatabaseUrl = "https://linuxvm-d10a3-default-rtdb.firebaseio.com"

    public let popularEmojis = ["❤️", "🔥", "🎧", "👏", "😂", "😮", "🚀", "✨", "🎵"]

    public let defaultRooms: [ChatRoom] = [
        ChatRoom(id: "room_global", name: "Global Music Lounge", description: "Live music discussions & real-time song sharing", activeListeners: 18),
        ChatRoom(id: "room_late_night", name: "Late Night Vibes", description: "Lo-fi beats, synthwave, and midnight conversations", activeListeners: 9),
        ChatRoom(id: "room_edm", name: "Bass & Electronic", description: "Fast tempos, heavy drops, and hype tracks", activeListeners: 14)
    ]

    @Published public var currentProfile: RoomProfile?
    @Published public var currentRoom: ChatRoom
    @Published public var messages: [ChatMessage] = []

    private var syncTimer: Timer?

    private init() {
        self.currentRoom = defaultRooms[0]
    }

    public func joinRoom(name: String, dob: String, room: ChatRoom? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "AuraListener" : name
        let trimmedDob = dob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "01/01/2000" : dob

        let selected = room ?? defaultRooms[0]
        self.currentProfile = RoomProfile(name: trimmedName, dob: trimmedDob)
        self.currentRoom = selected

        let welcome = ChatMessage(
            id: "sys_welcome_\(Int(Date().timeIntervalSince1970 * 1000))",
            senderId: "system",
            senderName: "Aura Room Bot",
            text: "🎉 Welcome \(trimmedName) to #\(selected.name)! Share any YouTube Music song live, chat, or react with emojis.",
            reactions: ["✨": 1],
            isFromMe: false
        )
        self.messages = [welcome]

        startLiveSync()
    }

    public func switchRoom(_ room: ChatRoom) {
        self.currentRoom = room
        self.messages = []
        startLiveSync()
    }

    public func leaveRoom() {
        syncTimer?.invalidate()
        syncTimer = nil
        currentProfile = nil
        messages = []
    }

    public func addReaction(to messageId: String, emoji: String) {
        guard let idx = messages.firstIndex(where: { $0.id == messageId }) else { return }
        var msg = messages[idx]
        msg.reactions[emoji, default: 0] += 1
        messages[idx] = msg

        broadcastMessage(msg)
    }

    public func sendMessage(text: String, sharedSong: Song? = nil) {
        guard let profile = currentProfile else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sharedSong != nil else { return }

        let newMsg = ChatMessage(
            id: "msg_\(Int(Date().timeIntervalSince1970 * 1000))",
            senderId: profile.userId,
            senderName: profile.name,
            text: text,
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
        syncTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.pollRoomUpdates()
        }
    }

    private func broadcastMessage(_ message: ChatMessage) {
        let roomId = currentRoom.id
        guard let payloadData = try? JSONEncoder().encode(message) else { return }

        // 1. Send to Firebase
        if let fbUrl = URL(string: "\(firebaseDatabaseUrl)/rooms/\(roomId)/messages/\(message.id).json") {
            var req = URLRequest(url: fbUrl)
            req.httpMethod = "PUT"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = payloadData
            URLSession.shared.dataTask(with: req).resume()
        }

        // 2. Send to instant realtime pubsub relay
        if let relayUrl = URL(string: "https://ntfy.sh/aura_music_\(roomId)") {
            var req = URLRequest(url: relayUrl)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = payloadData
            URLSession.shared.dataTask(with: req).resume()
        }
    }

    private func pollRoomUpdates() {
        guard let profile = currentProfile else { return }
        guard let url = URL(string: "https://ntfy.sh/aura_music_\(currentRoom.id)/json?poll=1&since=1m") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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

                if parsed.senderId != profile.userId {
                    var copy = parsed
                    // copy is not from me
                    newMessages.append(copy)
                }
            }

            if !newMessages.isEmpty {
                DispatchQueue.main.async {
                    var map = Dictionary(uniqueKeysWithValues: self.messages.map { ($0.id, $0) })
                    for m in newMessages {
                        map[m.id] = m
                    }
                    self.messages = map.values.sorted(by: { $0.timestamp < $1.timestamp })
                }
            }
        }.resume()
    }
}
