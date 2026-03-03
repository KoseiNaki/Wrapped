// File: Models/APIResponses.swift
import Foundation

// MARK: - Auth Responses

struct LoginResponse: Codable {
    let authURL: String
    let state: String
    
    enum CodingKeys: String, CodingKey {
        case authURL = "auth_url"
        case state
    }
}

struct TokenResponse: Codable {
    let token: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case token = "session_token"
        case altToken = "jwt"
        case altToken2 = "access_token"
        case expiresIn = "expires_in"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        
        // Try session_token first (backend uses this), then jwt, then access_token
        if let sessionToken = try? container.decode(String.self, forKey: .token) {
            token = sessionToken
        } else if let jwt = try? container.decode(String.self, forKey: .altToken) {
            token = jwt
        } else if let accessToken = try? container.decode(String.self, forKey: .altToken2) {
            token = accessToken
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .token,
                in: container,
                debugDescription: "No valid token field found (tried session_token, jwt, access_token)"
            )
        }
    }
}

// MARK: - User Profile Response

struct UserProfileResponse: Codable {
    let id: String
    let spotifyID: String
    let displayName: String?
    let syncEnabled: Bool
    let syncIntervalMinutes: Int
    let lastSyncAt: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case spotifyID = "spotify_id"
        case displayName = "display_name"
        case syncEnabled = "sync_enabled"
        case syncIntervalMinutes = "sync_interval_minutes"
        case lastSyncAt = "last_sync_at"
        case createdAt = "created_at"
    }
}

// MARK: - History Response

struct HistoryResponse: Codable {
    let items: [HistoryItemResponse]
    let total: Int
    let limit: Int
    let offset: Int
}

struct HistoryItemResponse: Codable {
    let id: String
    let track: TrackResponse
    let playedAt: String
    let contextType: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case track
        case playedAt = "played_at"
        case contextType = "context_type"
    }
}

struct TrackResponse: Codable {
    let id: String
    let name: String
    let durationMs: Int
    let explicit: Bool
    let album: AlbumResponse
    let artists: [ArtistResponse]
    
    enum CodingKeys: String, CodingKey {
        case id, name, explicit, album, artists
        case durationMs = "duration_ms"
    }
}

struct AlbumResponse: Codable {
    let id: String
    let name: String
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case imageURL = "image_url"
    }
}

struct ArtistResponse: Codable {
    let id: String
    let name: String
}

// MARK: - Sync Response

struct SyncResponse: Codable {
    let success: Bool
    let skipped: Bool?
    let reason: String?
    let pagesFetched: Int?
    let eventsInserted: Int?
    let duplicatesSkipped: Int?
    let potentialGap: Bool?
    
    enum CodingKeys: String, CodingKey {
        case success, skipped, reason
        case pagesFetched = "pagesFetched"
        case eventsInserted = "eventsInserted"
        case duplicatesSkipped = "duplicatesSkipped"
        case potentialGap = "potentialGap"
    }
}

// MARK: - Error Response

struct ErrorResponse: Codable {
    let error: String
    let message: String
    let details: AnyCodable?
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
