// File: Services/AppState.swift
import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var jwt: String?
    
    private let keychain = KeychainManager.shared
    private let api = APIClient.shared
    
    private init() {
        Task {
            await loadSession()
        }
    }
    
    // MARK: - Session Management
    
    func loadSession() async {
        isLoading = true
        
        do {
            // Try to get token from keychain
            guard let token = try keychain.getToken() else {
                print("No token in keychain")
                isLoading = false
                return
            }
            
            print("Found token in keychain, validating...")
            
            // Validate token by fetching profile
            do {
                let profile = try await api.getProfile(jwt: token)
                self.jwt = token
                self.currentUser = User(from: profile)
                self.isAuthenticated = true
                print("✅ Session restored")
            } catch APIError.unauthorized {
                // Token expired, try to refresh
                print("Token expired, attempting refresh...")
                try await refreshSession(currentToken: token)
            }
        } catch {
            print("Failed to load session: \(error)")
            try? keychain.deleteToken()
        }
        
        isLoading = false
    }
    
    private func refreshSession(currentToken: String) async throws {
        let tokenResponse = try await api.refreshJWT(currentJWT: currentToken)
        let newToken = tokenResponse.token
        
        try keychain.saveToken(newToken)
        
        let profile = try await api.getProfile(jwt: newToken)
        self.jwt = newToken
        self.currentUser = User(from: profile)
        self.isAuthenticated = true
        print("✅ Session refreshed")
    }
    
    // MARK: - Auth Flow
    
    func exchangeCodeForToken(code: String) async throws {
        let tokenResponse = try await api.exchangeTempCodeForJWT(tempCode: code)
        let token = tokenResponse.token
        
        // Save to keychain
        try keychain.saveToken(token)
        
        // Fetch profile
        let profile = try await api.getProfile(jwt: token)
        
        self.jwt = token
        self.currentUser = User(from: profile)
        self.isAuthenticated = true
        
        print("✅ Authentication complete")
    }
    
    func logout() {
        do {
            try keychain.deleteToken()
        } catch {
            print("Failed to delete token: \(error)")
        }
        
        self.jwt = nil
        self.currentUser = nil
        self.isAuthenticated = false
        
        print("Logged out")
    }
    
    // MARK: - Auto-Refresh on 401
    
    func performAuthenticatedRequest<T>(_ request: (String) async throws -> T) async throws -> T {
        guard let token = jwt else {
            throw APIError.unauthorized
        }
        
        do {
            return try await request(token)
        } catch APIError.unauthorized {
            print("Got 401, attempting auto-refresh...")
            
            // Try to refresh
            try await refreshSession(currentToken: token)
            
            guard let newToken = jwt else {
                throw APIError.unauthorized
            }
            
            // Retry once with new token
            return try await request(newToken)
        }
    }
}
