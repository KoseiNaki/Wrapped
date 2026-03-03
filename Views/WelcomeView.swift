import SwiftUI

struct WelcomeView: View {
    @State private var isLoggingIn = false
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        ZStack {
            // Background - Soft off-white with emerald gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    AppTheme.backgroundPrimary,
                    AppTheme.backgroundSecondary
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 48) {
                Spacer()

                // Logo and title
                VStack(spacing: 24) {
                    // Waveform icon with emerald and gold rings
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppTheme.emeraldBase, AppTheme.emeraldMid]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 140, height: 140)

                        Circle()
                            .stroke(AppTheme.goldMetallic, lineWidth: 2)
                            .frame(width: 120, height: 120)

                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppTheme.emeraldBase, AppTheme.emeraldDark]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(AppTheme.goldMetallic.opacity(0.3))
                                    .blendMode(.overlay)
                            )
                    }

                    VStack(spacing: 12) {
                        Text("Wrapped")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(AppTheme.emeraldDarkest)

                        Text("Your Spotify story, beautifully told")
                            .font(.system(size: 17))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                // Login button
                VStack(spacing: 16) {
                    Button {
                        Task {
                            await authViewModel.startLogin()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if authViewModel.isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.goldMetallic))
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            Text("Connect with Spotify")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [AppTheme.emeraldBase, AppTheme.emeraldDark]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(AppTheme.goldMetallic)
                        .cornerRadius(12)
                        .shadow(color: AppTheme.emeraldBase.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                    .disabled(authViewModel.isAuthenticating)

                    Text("We never post without permission")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textTertiary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.light)
        .alert("Error", isPresented: $authViewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authViewModel.errorMessage ?? "Unknown error")
        }
    }
}

#Preview {
    WelcomeView()
}
