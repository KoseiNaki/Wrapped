import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showingImagePicker = false
    @State private var showingEditName = false
    @State private var editedName = ""
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.spacing24) {
                    // Profile Header
                    profileHeader

                    // Stats Overview
                    statsSection

                    // Sync Settings
                    syncSection

                    // Preferences
                    preferencesSection

                    // Account
                    accountSection
                }
                .padding(.horizontal, Spacing.spacing16)
                .padding(.bottom, Spacing.spacing32)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color.emerald600)
                }
            }
        }
        .onAppear {
            viewModel.loadProfile()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $viewModel.selectedImage, onImageSelected: {
                viewModel.uploadProfileImage()
            })
        }
        .alert("Edit Display Name", isPresented: $showingEditName) {
            TextField("Display Name", text: $editedName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                viewModel.updateDisplayName(editedName)
            }
        } message: {
            Text("Enter your custom display name")
        }
        .alert("Logout", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                viewModel.logout()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteAccount()
                dismiss()
            }
        } message: {
            Text("This will permanently delete your account and all listening history. This cannot be undone.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: Spacing.spacing16) {
            // Profile Image
            ZStack(alignment: .bottomTrailing) {
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else if let imageUrl = viewModel.profile?.profileImageUrl,
                          let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.emerald100)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color.emerald400)
                            )
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.emerald100)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color.emerald400)
                        )
                }

                // Edit button
                Button(action: { showingImagePicker = true }) {
                    Circle()
                        .fill(Color.goldPrimary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        )
                }
            }

            // Display Name
            HStack(spacing: Spacing.spacing8) {
                Text(viewModel.profile?.displayName ?? "Loading...")
                    .font(.h2)
                    .foregroundColor(Color.textPrimary)

                Button(action: {
                    editedName = viewModel.profile?.customDisplayName ?? viewModel.profile?.displayName ?? ""
                    showingEditName = true
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.emerald400)
                }
            }

            // Member Since
            if let memberSince = viewModel.profile?.memberSince {
                Text("Member since \(formatDate(memberSince))")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
        }
        .padding(.vertical, Spacing.spacing24)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            Text("Stats Overview")
                .font(.h3)
                .foregroundColor(Color.textPrimary)

            HStack(spacing: Spacing.spacing16) {
                ProfileStatCard(
                    title: "Tracks",
                    value: "\(viewModel.profile?.totalTracksListened ?? 0)",
                    icon: "music.note"
                )

                ProfileStatCard(
                    title: "Listening Time",
                    value: viewModel.profile?.totalListeningTimeFormatted ?? "0 min",
                    icon: "clock.fill"
                )
            }
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            Text("Sync Settings")
                .font(.h3)
                .foregroundColor(Color.textPrimary)

            VStack(spacing: 0) {
                ProfileRow(
                    icon: "arrow.clockwise",
                    title: "Last Sync",
                    value: viewModel.profile?.lastSyncAt.map { formatRelativeDate($0) } ?? "Never"
                )

                Divider().padding(.leading, 44)

                ProfileRow(
                    icon: "clock",
                    title: "Next Sync",
                    value: viewModel.profile?.nextSyncAt.map { formatRelativeDate($0) } ?? "Pending"
                )

                Divider().padding(.leading, 44)

                ProfileRow(
                    icon: "checkmark.circle",
                    title: "Status",
                    value: viewModel.profile?.syncStatus?.capitalized ?? "Unknown"
                )

                Divider().padding(.leading, 44)

                Button(action: { viewModel.triggerSync() }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .frame(width: 24)
                            .foregroundColor(Color.emerald500)

                        Text("Sync Now")
                            .font(.bodyDefault)
                            .foregroundColor(Color.textPrimary)

                        Spacer()

                        if viewModel.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color.textTertiary)
                        }
                    }
                    .padding(.vertical, Spacing.spacing12)
                    .padding(.horizontal, Spacing.spacing16)
                }
                .disabled(viewModel.isSyncing)
            }
            .background(Color.surfaceCard)
            .cornerRadius(Radius.large)
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            Text("Preferences")
                .font(.h3)
                .foregroundColor(Color.textPrimary)

            VStack(spacing: 0) {
                NavigationLink(destination: SettingsView()) {
                    HStack {
                        Image(systemName: "gearshape")
                            .frame(width: 24)
                            .foregroundColor(Color.emerald500)

                        Text("App Settings")
                            .font(.bodyDefault)
                            .foregroundColor(Color.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color.textTertiary)
                    }
                    .padding(.vertical, Spacing.spacing12)
                    .padding(.horizontal, Spacing.spacing16)
                }

                Divider().padding(.leading, 44)

                Button(action: { exportData() }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 24)
                            .foregroundColor(Color.emerald500)

                        Text("Export Data")
                            .font(.bodyDefault)
                            .foregroundColor(Color.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color.textTertiary)
                    }
                    .padding(.vertical, Spacing.spacing12)
                    .padding(.horizontal, Spacing.spacing16)
                }
            }
            .background(Color.surfaceCard)
            .cornerRadius(Radius.large)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            Text("Account")
                .font(.h3)
                .foregroundColor(Color.textPrimary)

            VStack(spacing: 0) {
                Link(destination: URL(string: "https://koseinaki.github.io/Wrapped/privacy-policy.html")!) {
                    HStack {
                        Image(systemName: "hand.raised")
                            .frame(width: 24)
                            .foregroundColor(Color.emerald500)

                        Text("Privacy Policy")
                            .font(.bodyDefault)
                            .foregroundColor(Color.textPrimary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14))
                            .foregroundColor(Color.textTertiary)
                    }
                    .padding(.vertical, Spacing.spacing12)
                    .padding(.horizontal, Spacing.spacing16)
                }

                Divider().padding(.leading, 44)

                Button(action: { showingLogoutAlert = true }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .frame(width: 24)
                            .foregroundColor(Color.goldMuted)

                        Text("Logout")
                            .font(.bodyDefault)
                            .foregroundColor(Color.goldMuted)

                        Spacer()
                    }
                    .padding(.vertical, Spacing.spacing12)
                    .padding(.horizontal, Spacing.spacing16)
                }

                Divider().padding(.leading, 44)

                Button(action: { showingDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                            .frame(width: 24)
                            .foregroundColor(Color.destructive)

                        Text("Delete Account")
                            .font(.bodyDefault)
                            .foregroundColor(Color.destructive)

                        Spacer()
                    }
                    .padding(.vertical, Spacing.spacing12)
                    .padding(.horizontal, Spacing.spacing16)
                }
            }
            .background(Color.surfaceCard)
            .cornerRadius(Radius.large)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM d, yyyy"
        return displayFormatter.string(from: date)
    }

    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM d, yyyy, HH:mm"
        return displayFormatter.string(from: date)
    }

    private func exportData() {
        // TODO: Implement data export
    }
}

// MARK: - Supporting Views

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: Spacing.spacing8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color.goldPrimary)

            Text(value)
                .font(.h3)
                .foregroundColor(Color.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.spacing16)
        .background(Color.surfaceCard)
        .cornerRadius(Radius.large)
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(Color.emerald500)

            Text(title)
                .font(.bodyDefault)
                .foregroundColor(Color.textPrimary)

            Spacer()

            Text(value)
                .font(.bodyDefault)
                .foregroundColor(Color.textSecondary)
        }
        .padding(.vertical, Spacing.spacing12)
        .padding(.horizontal, Spacing.spacing16)
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImageSelected: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                DispatchQueue.main.async {
                    self?.parent.image = image as? UIImage
                    self?.parent.onImageSelected()
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
