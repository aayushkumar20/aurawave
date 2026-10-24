import Foundation
import Combine

public final class ChatService: ObservableObject {
    public static let shared = ChatService()

    public var firebaseDatabaseUrl = "https://aura-music-app-default-rtdb.firebaseio.com"

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

        startFirebaseSync()
    }

    public func switchRoom(_ room: ChatRoom) {
        self.currentRoom = room
        self.messages = []
        startFirebaseSync()
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

        syncToFirebase(message: msg)
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
        syncToFirebase(message: newMsg)
    }

    private func startFirebaseSync() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchMessagesFromFirebase()
        }
    }

    private func fetchMessagesFromFirebase() {
        guard let profile = currentProfile else { return }
        guard let url = URL(string: "\(firebaseDatabaseUrl)/rooms/\(currentRoom.id)/messages.json") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }

            var fetched: [ChatMessage] = []
            for (key, dict) in json {
                let id = dict["id"] as? String ?? key
                let senderId = dict["senderId"] as? String ?? ""
                let senderName = dict["senderName"] as? String ?? "User"
                let text = dict["text"] as? String ?? ""
                let timestampVal = dict["timestamp"] as? Double ?? Date().timeIntervalSince1970
                let isMe = senderId == profile.userId

                fetched.append(
                    ChatMessage(
                        id: id,
                        senderId: senderId,
                        senderName: senderName,
                        text: text,
                        timestamp: Date(timeIntervalSince1970: timestampVal),
                        sharedSong: nil,
                        reactions: [:],
                        isFromMe: isMe
                    )
                )
            }

            if !fetched.isEmpty {
                DispatchQueue.main.async {
                    var map = Dictionary(uniqueKeysWithValues: self.messages.map { ($0.id, $0) })
                    for item in fetched {
                        if map[item.id] == nil {
                            map[item.id] = item
                        }
                    }
                    self.messages = map.values.sorted(by: { $0.timestamp < $1.timestamp })
                }
            }
        }.resume()
    }

    private func syncToFirebase(message: ChatMessage) {
        guard let url = URL(string: "\(firebaseDatabaseUrl)/rooms/\(currentRoom.id)/messages/\(message.id).json") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "id": message.id,
            "senderId": message.senderId,
            "senderName": message.senderName,
            "text": message.text,
            "timestamp": message.timestamp.timeIntervalSince1970,
            "reactions": message.reactions,
            "isFromMe": message.isFromMe
        ]

        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req).resume()
    }
}
