// File: WrappedApp.swift
import SwiftUI
import UIKit

@main
struct WrappedApp: App {
    @StateObject private var appState = AppState.shared
    @State private var hasCompletedOnboarding = OnboardingManager.hasCompletedOnboarding

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoading {
                    // Premium loading screen
                    LoadingView()
                } else if !hasCompletedOnboarding {
                    // Show onboarding for first-time users
                    OnboardingView {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .transition(.opacity)
                } else if appState.isAuthenticated {
                    HomeView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    LoginView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appState.isAuthenticated)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasCompletedOnboarding)
            .tint(.goldPrimary)
            .preferredColorScheme(.light)
            .onAppear {
                configureNavigationBar()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }

    private func configureNavigationBar() {
        // Transparent nav bar — each view controls its own header
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.emerald900)]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "wrapped",
              url.host == "oauth",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }

        Task {
            do {
                try await appState.exchangeCodeForToken(code: code)
            } catch {
                print("Failed to exchange code: \(error)")
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [Color.emerald800, Color.emerald900],
                startPoint: isAnimating ? .topLeading : .bottomLeading,
                endPoint: isAnimating ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }

            VStack(spacing: Spacing.spacing24) {
                // Animated logo
                ZStack {
                    // Pulse rings
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .stroke(Color.goldPrimary.opacity(0.3), lineWidth: 2)
                            .frame(width: 80 + CGFloat(i * 30), height: 80 + CGFloat(i * 30))
                            .scaleEffect(pulseScale)
                            .opacity(2 - pulseScale)
                    }

                    // Main icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.goldPrimary, Color.goldLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.goldPrimary.opacity(0.5), radius: 16)

                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.emerald900)
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        pulseScale = 1.5
                    }
                }

                // Loading indicator
                ProgressView()
                    .tint(.goldPrimary)
                    .scaleEffect(1.2)
            }
        }
    }
}
