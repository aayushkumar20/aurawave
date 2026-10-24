import Foundation

public struct Song: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let durationText: String
    public let durationSeconds: Double
    public let thumbnailUrl: String
    public var streamUrl: String?
    public var isFavorite: Bool

    public init(
        id: String,
        title: String,
        artist: String,
        album: String = "YouTube Music Single",
        durationText: String = "3:30",
        durationSeconds: Double = 210,
        thumbnailUrl: String,
        streamUrl: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.durationText = durationText
        self.durationSeconds = durationSeconds
        self.thumbnailUrl = thumbnailUrl
        self.streamUrl = streamUrl
        self.isFavorite = isFavorite
    }
}

public struct Playlist: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var description: String
    public var coverUrl: String
    public var songs: [Song]

    public init(id: String, name: String, description: String, coverUrl: String, songs: [Song]) {
        self.id = id
        self.name = name
        self.description = description
        self.coverUrl = coverUrl
        self.songs = songs
    }
}

public struct RoomProfile: Identifiable, Codable, Equatable {
    public var id: String { userId }
    public let name: String
    public let dob: String
    public let userId: String
    public let avatarUrl: String

    public init(name: String, dob: String) {
        self.name = name
        self.dob = dob
        self.userId = "user_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))_\(dob.replacingOccurrences(of: "/", with: "").replacingOccurrences(of: "-", with: ""))"
        self.avatarUrl = "https://api.dicebear.com/7.x/bottts/png?seed=\(name)"
    }
}

public struct ChatRoom: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let activeListeners: Int

    public init(id: String, name: String, description: String, activeListeners: Int = 1) {
        self.id = id
        self.name = name
        self.description = description
        self.activeListeners = activeListeners
    }
}

public struct ChatMessage: Identifiable, Codable, Equatable {
    public let id: String
    public let senderId: String
    public let senderName: String
    public let text: String
    public let timestamp: Date
    public let sharedSong: Song?
    public var reactions: [String: Int]
    public let isFromMe: Bool

    public init(
        id: String,
        senderId: String,
        senderName: String,
        text: String,
        timestamp: Date = Date(),
        sharedSong: Song? = nil,
        reactions: [String: Int] = [:],
        isFromMe: Bool = false
    ) {
        self.id = id
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.sharedSong = sharedSong
        self.reactions = reactions
        self.isFromMe = isFromMe
    }
}

public enum RepeatMode: String, CaseIterable {
    case off
    case all
    case one
}
