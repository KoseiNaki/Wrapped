// File: Models/User.swift
import Foundation

struct User: Identifiable {
    let id: String
    let spotifyID: String
    let displayName: String?
    let syncEnabled: Bool
    let syncIntervalMinutes: Int
    let lastSyncAt: Date?
    let createdAt: Date
    
    init(from response: UserProfileResponse) {
        self.id = response.id
        self.spotifyID = response.spotifyID
        self.displayName = response.displayName
        self.syncEnabled = response.syncEnabled
        self.syncIntervalMinutes = response.syncIntervalMinutes
        
        let formatter = ISO8601DateFormatter()
        self.lastSyncAt = response.lastSyncAt.flatMap { formatter.date(from: $0) }
        self.createdAt = formatter.date(from: response.createdAt) ?? Date()
    }
}
