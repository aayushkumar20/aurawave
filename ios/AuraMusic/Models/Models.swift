import Foundation

public struct Song: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let durationText: String
    public let durationSeconds: Double
    public let durationMs: Double
    public let thumbnailUrl: String
    public var streamUrl: String?
    public var isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, durationText, durationSeconds, durationMs, thumbnailUrl, streamUrl, isFavorite
    }

    public init(
        id: String,
        title: String,
        artist: String,
        album: String = "YouTube Music Single",
        durationText: String = "3:30",
        durationSeconds: Double = 210,
        durationMs: Double? = nil,
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
        self.durationMs = durationMs ?? (durationSeconds * 1000.0)
        self.thumbnailUrl = thumbnailUrl
        self.streamUrl = streamUrl
        self.isFavorite = isFavorite
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Unknown Song"
        artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? "Unknown Artist"
        album = try container.decodeIfPresent(String.self, forKey: .album) ?? "YouTube Music Single"
        durationText = try container.decodeIfPresent(String.self, forKey: .durationText) ?? "3:30"
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl) ?? ""
        streamUrl = try container.decodeIfPresent(String.self, forKey: .streamUrl)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false

        // Cross-platform duration compatibility
        if let sec = try? container.decode(Double.self, forKey: .durationSeconds) {
            durationSeconds = sec
            durationMs = (try? container.decode(Double.self, forKey: .durationMs)) ?? (sec * 1000.0)
        } else if let ms = try? container.decode(Double.self, forKey: .durationMs) {
            durationMs = ms
            durationSeconds = ms / 1000.0
        } else {
            durationSeconds = 210.0
            durationMs = 210000.0
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encode(album, forKey: .album)
        try container.encode(durationText, forKey: .durationText)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(durationMs, forKey: .durationMs)
        try container.encode(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(streamUrl, forKey: .streamUrl)
        try container.encode(isFavorite, forKey: .isFavorite)
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
    public var isFromMe: Bool

    enum CodingKeys: String, CodingKey {
        case id, senderId, senderName, text, timestamp, sharedSong, reactions, isFromMe
    }

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        senderId = try container.decodeIfPresent(String.self, forKey: .senderId) ?? ""
        senderName = try container.decodeIfPresent(String.self, forKey: .senderName) ?? "Aura User"
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        sharedSong = try container.decodeIfPresent(Song.self, forKey: .sharedSong)
        reactions = try container.decodeIfPresent([String: Int].self, forKey: .reactions) ?? [:]
        isFromMe = try container.decodeIfPresent(Bool.self, forKey: .isFromMe) ?? false

        // Cross-platform timestamp handling (epoch ms, epoch seconds, or ISO Date)
        if let tsDouble = try? container.decode(Double.self, forKey: .timestamp) {
            if tsDouble > 100_000_000_000 { // Milliseconds
                timestamp = Date(timeIntervalSince1970: tsDouble / 1000.0)
            } else { // Seconds
                timestamp = Date(timeIntervalSince1970: tsDouble)
            }
        } else if let dateVal = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = dateVal
        } else {
            timestamp = Date()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(senderId, forKey: .senderId)
        try container.encode(senderName, forKey: .senderName)
        try container.encode(text, forKey: .text)
        // Store timestamp as Unix milliseconds (standard across Android & Web)
        try container.encode(timestamp.timeIntervalSince1970 * 1000.0, forKey: .timestamp)
        try container.encodeIfPresent(sharedSong, forKey: .sharedSong)
        try container.encode(reactions, forKey: .reactions)
        try container.encode(isFromMe, forKey: .isFromMe)
    }
}

public enum RepeatMode: String, CaseIterable {
    case off
    case all
    case one
}
