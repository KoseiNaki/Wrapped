import SwiftUI
import UIKit
import Combine

struct UserProfile {
    let id: String
    let spotifyId: String
    let displayName: String?
    let customDisplayName: String?
    let spotifyDisplayName: String?
    let profileImageUrl: String?
    let customProfileImageUrl: String?
    let spotifyProfileImageUrl: String?
    let totalTracksListened: Int
    let totalListeningTimeMs: Int
    let totalListeningTimeFormatted: String?
    let syncEnabled: Bool
    let lastSyncAt: String?
    let nextSyncAt: String?
    let syncStatus: String?
    let lastSyncError: String?
    let memberSince: String?
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var error: String?
    @Published var selectedImage: UIImage?

    private let appState = AppState.shared

    // Local image storage
    private var localImageURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("profile_image.jpg")
    }

    init() {
        loadLocalImage()
    }

    private func loadLocalImage() {
        if FileManager.default.fileExists(atPath: localImageURL.path),
           let data = try? Data(contentsOf: localImageURL),
           let image = UIImage(data: data) {
            selectedImage = image
        }
    }

    private func saveLocalImage(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: localImageURL)
        }
    }

    private func deleteLocalImage() {
        try? FileManager.default.removeItem(at: localImageURL)
    }

    func loadProfile() {
        guard let token = appState.jwt else { return }

        isLoading = true
        error = nil

        Task {
            do {
                var request = URLRequest(url: AppConfig.meURL)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load profile"])
                }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

                profile = UserProfile(
                    id: json["id"] as? String ?? "",
                    spotifyId: json["spotify_id"] as? String ?? "",
                    displayName: json["display_name"] as? String,
                    customDisplayName: json["custom_display_name"] as? String,
                    spotifyDisplayName: json["spotify_display_name"] as? String,
                    profileImageUrl: json["profile_image_url"] as? String,
                    customProfileImageUrl: json["custom_profile_image_url"] as? String,
                    spotifyProfileImageUrl: json["spotify_profile_image_url"] as? String,
                    totalTracksListened: json["total_tracks_listened"] as? Int ?? 0,
                    totalListeningTimeMs: json["total_listening_time_ms"] as? Int ?? 0,
                    totalListeningTimeFormatted: json["total_listening_time_formatted"] as? String,
                    syncEnabled: json["sync_enabled"] as? Bool ?? true,
                    lastSyncAt: json["last_sync_at"] as? String,
                    nextSyncAt: json["next_sync_at"] as? String,
                    syncStatus: json["sync_status"] as? String,
                    lastSyncError: json["last_sync_error"] as? String,
                    memberSince: json["member_since"] as? String
                )

                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    func updateDisplayName(_ name: String) {
        guard let token = appState.jwt else { return }

        Task {
            do {
                var request = URLRequest(url: URL(string: "\(AppConfig.baseURL)/me/profile")!)
                request.httpMethod = "PATCH"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any?] = ["display_name": name.isEmpty ? nil : name]
                request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update name"])
                }

                // Reload profile
                loadProfile()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func uploadProfileImage() {
        guard let image = selectedImage else { return }

        // Save locally first (so it persists even if backend fails)
        saveLocalImage(image)

        // Try to upload to backend if we have a token
        guard let token = appState.jwt else { return }

        Task {
            do {
                // Compress and encode image
                guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
                let base64String = "data:image/jpeg;base64," + imageData.base64EncodedString()

                var request = URLRequest(url: URL(string: "\(AppConfig.baseURL)/me/profile")!)
                request.httpMethod = "PATCH"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = ["profile_image": base64String]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("Backend image upload failed, but image saved locally")
                    return
                }

                // Reload profile
                loadProfile()
            } catch {
                print("Backend image upload error: \(error.localizedDescription)")
                // Image is still saved locally, so don't show error to user
            }
        }
    }

    func triggerSync() {
        guard let token = appState.jwt else { return }

        isSyncing = true

        Task {
            do {
                var request = URLRequest(url: AppConfig.syncNowURL)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sync failed"])
                }

                if httpResponse.statusCode == 429 {
                    self.error = "Please wait before syncing again"
                }

                isSyncing = false
                loadProfile() // Refresh profile to show new sync time
            } catch {
                self.error = error.localizedDescription
                isSyncing = false
            }
        }
    }

    func logout() {
        deleteLocalImage()
        selectedImage = nil
        appState.logout()
    }

    func deleteAccount() {
        guard let token = appState.jwt else { return }

        Task {
            do {
                var request = URLRequest(url: AppConfig.meURL)
                request.httpMethod = "DELETE"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (_, _) = try await URLSession.shared.data(for: request)

                // Clear local data and logout after deletion
                deleteLocalImage()
                selectedImage = nil
                appState.logout()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
