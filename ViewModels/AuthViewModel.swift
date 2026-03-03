// File: ViewModels/AuthViewModel.swift
import Foundation
import AuthenticationServices
import SwiftUI
import Combine

@MainActor
class AuthViewModel: NSObject, ObservableObject {
    @Published var isAuthenticating = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let api = APIClient.shared
    private let appState = AppState.shared
    
    private var authSession: ASWebAuthenticationSession?
    
    // MARK: - Login Flow
    
    func startLogin() async {
        isAuthenticating = true
        errorMessage = nil
        showError = false
        
        do {
            // Step 1: Get auth URL from backend
            let loginResponse = try await api.getAuthLoginURL()
            
            guard let authURL = URL(string: loginResponse.authURL) else {
                throw APIError.invalidURL
            }
            
            print("Opening Spotify auth: \(authURL)")
            
            // Step 2: Open auth URL in ASWebAuthenticationSession
            try await openAuthSession(url: authURL)
            
        } catch {
            print("Login failed: \(error)")
            errorMessage = error.localizedDescription
            showError = true
            isAuthenticating = false
        }
    }
    
    private func openAuthSession(url: URL) async throws {
        let code: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "wrapped"
            ) { callbackURL, error in
                if let error = error {
                    // User cancelled
                    if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        print("❌ User cancelled login")
                        continuation.resume(throwing: APIError.serverError("Login cancelled"))
                    } else {
                        print("❌ Auth session error: \(error)")
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    print("❌ No callback URL received")
                    continuation.resume(throwing: APIError.serverError("No response from Spotify"))
                    return
                }

                print("✅ Got callback URL: \(callbackURL)")

                // Extract code from callback URL: wrapped://oauth?code=xxx
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                    print("❌ Could not parse callback URL")
                    continuation.resume(throwing: APIError.serverError("Invalid callback URL"))
                    return
                }

                print("📋 Callback components: \(components)")
                print("📋 Query items: \(String(describing: components.queryItems))")

                // Check for error in callback
                if let errorParam = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    print("❌ Spotify returned error: \(errorParam)")
                    continuation.resume(throwing: APIError.serverError("Spotify error: \(errorParam)"))
                    return
                }

                guard let codeParam = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    print("❌ No code in callback URL. Query items: \(String(describing: components.queryItems))")
                    continuation.resume(throwing: APIError.serverError("No authorization code received"))
                    return
                }

                print("✅ Got auth code: \(codeParam.prefix(10))...")
                continuation.resume(returning: codeParam)
            }
            
            // Use ephemeral session to avoid cookie issues
            session.prefersEphemeralWebBrowserSession = true

            // Set presentation context
            session.presentationContextProvider = self

            self.authSession = session

            // Start the session
            session.start()
        }

        // Exchange code for token
        print("Exchanging code for token...")
        try await appState.exchangeCodeForToken(code: code)
        isAuthenticating = false
        print("✅ Authentication complete")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthViewModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the first window scene's first window
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return windowScene?.windows.first ?? ASPresentationAnchor()
    }
}
