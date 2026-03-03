// File: Services/APIClient.swift
import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized - please log in again"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }
    
    // MARK: - Auth Endpoints
    
    func getAuthLoginURL() async throws -> LoginResponse {
        let url = AppConfig.authLoginURL
        
        print("🔑 Fetching auth URL from: \(url)")
        
        let (data, response) = try await session.data(from: url)
        
        try validateResponse(response)
        
        let loginResponse = try decoder.decode(LoginResponse.self, from: data)
        print("✅ Got auth URL")
        return loginResponse
    }
    
    func exchangeTempCodeForJWT(tempCode: String) async throws -> TokenResponse {
        let url = AppConfig.authTokenURL
        
        print("🔑 Exchanging temp code for JWT")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["code": tempCode]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        print("✅ Got JWT token")
        return tokenResponse
    }
    
    func refreshJWT(currentJWT: String) async throws -> TokenResponse {
        let url = AppConfig.authRefreshURL
        
        print("🔄 Refreshing JWT")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentJWT)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        try validateResponse(response)
        
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        print("✅ JWT refreshed")
        return tokenResponse
    }
    
    // MARK: - User Endpoints
    
    func getProfile(jwt: String) async throws -> UserProfileResponse {
        let url = AppConfig.meURL
        
        print("👤 Fetching profile")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        // Handle 401 by throwing unauthorized
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        try validateResponse(response)
        
        let profile = try decoder.decode(UserProfileResponse.self, from: data)
        print("✅ Got profile: \(profile.displayName ?? "no name")")
        return profile
    }
    
    func getHistory(jwt: String, limit: Int = 50, offset: Int = 0) async throws -> HistoryResponse {
        let url = AppConfig.meHistoryURL(limit: limit, offset: offset)
        
        print("📜 Fetching history (limit: \(limit), offset: \(offset))")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        try validateResponse(response)
        
        let history = try decoder.decode(HistoryResponse.self, from: data)
        print("✅ Got \(history.items.count) history items (total: \(history.total))")
        return history
    }
    
    func getStats(jwt: String, period: String = "7d", offset: Int = 0) async throws -> StatsResponse {
        let url = AppConfig.meStatsURL(period: period, offset: offset)

        print("📊 Fetching stats (period: \(period), offset: \(offset))")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        try validateResponse(response)
        
        let stats = try decoder.decode(StatsResponse.self, from: data)
        print("✅ Got stats with \(stats.topArtists.count) top artists")
        return stats
    }
    
    func devSyncNow(jwt: String) async throws -> SyncResponse {
        let url = AppConfig.syncNowURL  // Use production sync endpoint

        print("🔄 Triggering manual sync")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        // Handle rate limiting (429) with a friendly message
        if httpResponse.statusCode == 429 {
            // Try to get the message from the response
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                throw APIError.serverError(message)
            }
            throw APIError.serverError("Please wait 5 minutes between syncs")
        }

        // Handle other errors
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                throw APIError.serverError(message)
            }
            throw APIError.serverError("Status code: \(httpResponse.statusCode)")
        }

        let syncResponse = try decoder.decode(SyncResponse.self, from: data)
        print("✅ Sync completed: \(syncResponse.success)")
        return syncResponse
    }
    
    // MARK: - Helper Methods
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError("Status code: \(httpResponse.statusCode)")
        }
    }
}
