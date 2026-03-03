// File: Models/ListeningEvent.swift
import Foundation

struct AudioFeatures {
    let danceability: Double?
    let energy: Double?
    let valence: Double?  // Happiness/positivity
    let tempo: Double?    // BPM
    let acousticness: Double?
    let instrumentalness: Double?
    let speechiness: Double?
    let liveness: Double?
    let loudness: Double?
    let key: Int?
    let mode: Int?  // 0 = minor, 1 = major
    let timeSignature: Int?

    init?(from response: AudioFeaturesResponse?) {
        guard let r = response else { return nil }
        self.danceability = r.danceability
        self.energy = r.energy
        self.valence = r.valence
        self.tempo = r.tempo
        self.acousticness = r.acousticness
        self.instrumentalness = r.instrumentalness
        self.speechiness = r.speechiness
        self.liveness = r.liveness
        self.loudness = r.loudness
        self.key = r.key
        self.mode = r.mode
        self.timeSignature = r.timeSignature
    }

    // Human-readable descriptions
    var moodDescription: String {
        guard let v = valence else { return "Unknown" }
        switch v {
        case 0..<0.3: return "Sad/Dark"
        case 0.3..<0.5: return "Melancholic"
        case 0.5..<0.7: return "Neutral"
        case 0.7..<0.85: return "Happy"
        default: return "Euphoric"
        }
    }

    var energyDescription: String {
        guard let e = energy else { return "Unknown" }
        switch e {
        case 0..<0.3: return "Chill"
        case 0.3..<0.6: return "Moderate"
        case 0.6..<0.8: return "Energetic"
        default: return "Intense"
        }
    }

    var tempoDescription: String {
        guard let t = tempo else { return "Unknown" }
        return "\(Int(t)) BPM"
    }
}

struct ListeningEvent: Identifiable {
    let id: String
    let trackName: String
    let trackID: String
    let albumName: String
    let albumImageURL: String?
    let artistNames: [String]
    let playedAt: Date
    let durationMs: Int
    let isExplicit: Bool
    let contextType: String?
    let contextUri: String?
    let audioFeatures: AudioFeatures?

    init(from response: HistoryItemResponse) {
        self.id = response.id
        self.trackName = response.track.name
        self.trackID = response.track.id
        self.albumName = response.track.album.name
        self.albumImageURL = response.track.album.imageURL
        self.artistNames = response.track.artists.map { $0.name }
        self.durationMs = response.track.durationMs
        self.isExplicit = response.track.explicit
        self.contextType = response.contextType
        self.contextUri = response.contextUri
        self.audioFeatures = AudioFeatures(from: response.track.audioFeatures)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.playedAt = formatter.date(from: response.playedAt) ?? Date()
    }
    
    var artistsString: String {
        artistNames.joined(separator: ", ")
    }
    
    var formattedPlayedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: playedAt)
    }
    
    var durationString: String {
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Context helpers
    var contextIcon: String {
        guard let type = contextType else { return "music.note" }
        switch type {
        case "playlist": return "music.note.list"
        case "album": return "square.stack"
        case "artist": return "person.fill"
        case "collection": return "heart.fill"
        default: return "music.note"
        }
    }
    
    var contextLabel: String? {
        guard let type = contextType else { return nil }
        switch type {
        case "playlist": return "From playlist"
        case "album": return "From album"
        case "artist": return "From artist"
        case "collection": return "From liked songs"
        default: return "From \(type)"
        }
    }
}
