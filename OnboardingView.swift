// File: OnboardingView.swift
// Premium Onboarding System for Wrapped
import SwiftUI
import Combine

// MARK: - Onboarding State Management

enum OnboardingStep: Int, CaseIterable {
    case splash = 0
    case valueIntro1 = 1  // "See Your Listening Story"
    case valueIntro2 = 2  // "Discover Patterns"
    case valueIntro3 = 3  // "Private. Secure. Yours."
    case spotifyLogin = 4
    case permissionExplain = 5
    case initialSync = 6
    case personalization = 7
    case welcome = 8
}

class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .splash
    @Published var isTransitioning = false
    @Published var syncProgress: Double = 0
    @Published var syncStatus: String = "Preparing..."
    @Published var isSyncing = false
    @Published var syncComplete = false
    @Published var syncError: String? = nil

    // Personalization data
    @Published var selectedGenres: Set<String> = []
    @Published var notificationsEnabled = true

    // User data preview
    @Published var previewArtist: String? = nil
    @Published var previewTrackCount: Int = 0

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "has_completed_onboarding_v2") }
        set { UserDefaults.standard.set(newValue, forKey: "has_completed_onboarding_v2") }
    }

    func nextStep() {
        guard !isTransitioning else { return }
        isTransitioning = true

        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            if let nextIndex = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextIndex
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
        }
    }

    func goToStep(_ step: OnboardingStep) {
        guard !isTransitioning else { return }
        isTransitioning = true

        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
            currentStep = step
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
        }
    }

    func startSync() {
        isSyncing = true
        syncProgress = 0
        syncStatus = "Connecting to Spotify..."
        syncError = nil

        // Perform real sync
        Task {
            await performRealSync()
        }
    }

    @MainActor
    private func performRealSync() async {
        let api = APIClient.shared
        let appState = AppState.shared

        guard let jwt = appState.jwt else {
            syncError = "Not authenticated"
            syncStatus = "Authentication required"
            return
        }

        do {
            // Step 1: Start sync
            updateProgress(0.1, status: "Connecting to Spotify...")

            // Step 2: Trigger sync
            updateProgress(0.25, status: "Fetching your recent tracks...")
            let syncResult = try await api.devSyncNow(jwt: jwt)

            if syncResult.success {
                let tracksFound = syncResult.eventsInserted ?? 0
                updateProgress(0.5, status: "Found \(tracksFound) tracks...")
            } else if syncResult.skipped == true {
                // Already synced recently, that's okay
                updateProgress(0.5, status: "Your data is up to date...")
            }

            // Step 3: Fetch stats to get preview data
            updateProgress(0.7, status: "Analyzing your music taste...")
            let stats = try await api.getStats(jwt: jwt, period: "7d")

            // Step 4: Complete
            updateProgress(0.9, status: "Finishing up...")

            try? await Task.sleep(nanoseconds: 500_000_000) // Brief pause for effect

            updateProgress(1.0, status: "Complete!")

            // Set preview data from real stats
            if let topArtist = stats.topArtists.first {
                previewArtist = topArtist.name
            }
            previewTrackCount = stats.totalTracks

            try? await Task.sleep(nanoseconds: 500_000_000)
            syncComplete = true

        } catch {
            print("❌ Sync error: \(error)")

            // Handle specific errors gracefully
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(let message) where message.contains("wait"):
                    // Rate limited - that's okay, continue anyway
                    updateProgress(0.5, status: "Checking your existing data...")
                    await fetchStatsOnly(jwt: jwt, api: api)
                    return
                default:
                    syncError = apiError.localizedDescription
                    syncStatus = "Sync issue - tap to retry"
                }
            } else {
                syncError = error.localizedDescription
                syncStatus = "Connection issue"
            }
        }
    }

    @MainActor
    private func fetchStatsOnly(jwt: String, api: APIClient) async {
        do {
            updateProgress(0.7, status: "Loading your stats...")
            let stats = try await api.getStats(jwt: jwt, period: "7d")

            updateProgress(1.0, status: "Complete!")

            if let topArtist = stats.topArtists.first {
                previewArtist = topArtist.name
            }
            previewTrackCount = stats.totalTracks

            try? await Task.sleep(nanoseconds: 500_000_000)
            syncComplete = true
        } catch {
            // Even if stats fail, let them continue
            updateProgress(1.0, status: "Ready!")
            previewTrackCount = 0
            try? await Task.sleep(nanoseconds: 500_000_000)
            syncComplete = true
        }
    }

    @MainActor
    private func updateProgress(_ progress: Double, status: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.syncProgress = progress
            self.syncStatus = status
        }
    }

    func completeOnboarding() {
        Self.hasCompletedOnboarding = true
        savePersonalization()
    }

    private func savePersonalization() {
        UserDefaults.standard.set(Array(selectedGenres), forKey: "onboarding_genres")
        UserDefaults.standard.set(notificationsEnabled, forKey: "onboarding_notifications")
    }
}

// MARK: - Main Onboarding Container

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager()
    @ObservedObject private var appState = AppState.shared
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Premium animated background
            OnboardingBackground(step: manager.currentStep)

            // Content based on current step
            switch manager.currentStep {
            case .splash:
                SplashScreen(manager: manager)

            case .valueIntro1:
                ValueIntroScreen(
                    manager: manager,
                    config: .listeningStory
                )

            case .valueIntro2:
                ValueIntroScreen(
                    manager: manager,
                    config: .discoverPatterns
                )

            case .valueIntro3:
                ValueIntroScreen(
                    manager: manager,
                    config: .privateSecure
                )

            case .spotifyLogin:
                SpotifyLoginScreen(manager: manager)

            case .permissionExplain:
                PermissionScreen(manager: manager)

            case .initialSync:
                SyncScreen(manager: manager)

            case .personalization:
                PersonalizationScreen(manager: manager)

            case .welcome:
                WelcomeScreen(manager: manager, onComplete: {
                    manager.completeOnboarding()
                    onComplete()
                })
            }
        }
        .ignoresSafeArea()
        .onReceive(appState.$isAuthenticated) { isAuthenticated in
            // When user successfully authenticates, move to permission screen
            print("🔑 Auth state changed: \(isAuthenticated), current step: \(manager.currentStep)")
            if isAuthenticated && manager.currentStep == .spotifyLogin {
                print("✅ Moving to permission screen")
                manager.goToStep(.permissionExplain)
            }
        }
    }
}

// MARK: - Premium Animated Background

struct OnboardingBackground: View {
    let step: OnboardingStep
    @State private var animateGradient = false
    @State private var particleOffset: CGFloat = 0

    private var gradientColors: [Color] {
        switch step {
        case .splash, .valueIntro1, .valueIntro2, .valueIntro3:
            return [Color.emerald900, Color(hex: "0A2F23"), Color.emerald800]
        case .spotifyLogin:
            return [Color(hex: "1DB954").opacity(0.3), Color.emerald900, Color(hex: "0A2F23")]
        case .permissionExplain, .initialSync:
            return [Color.emerald800, Color.emerald900, Color(hex: "0A2F23")]
        case .personalization, .welcome:
            return [Color.emerald900, Color.emerald800, Color(hex: "0F3D2E")]
        }
    }

    var body: some View {
        ZStack {
            // Animated gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateGradient)

            // Subtle particle overlay
            GeometryReader { geo in
                ForEach(0..<15, id: \.self) { i in
                    Circle()
                        .fill(Color.goldPrimary.opacity(0.03))
                        .frame(width: CGFloat.random(in: 50...150))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height) + particleOffset
                        )
                        .blur(radius: 20)
                }
            }

            // Noise texture overlay (subtle)
            Rectangle()
                .fill(Color.white.opacity(0.02))
        }
        .onAppear {
            animateGradient = true
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                particleOffset = 50
            }
        }
    }
}

// MARK: - Splash Screen

struct SplashScreen: View {
    @ObservedObject var manager: OnboardingManager
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var pulseRings: [Bool] = [false, false, false]

    var body: some View {
        VStack {
            Spacer()

            ZStack {
                // Pulse rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.goldPrimary.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 120 + CGFloat(i * 50), height: 120 + CGFloat(i * 50))
                        .scaleEffect(pulseRings[i] ? 1.3 : 1)
                        .opacity(pulseRings[i] ? 0 : 0.6)
                }

                // Logo container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.goldPrimary, Color.goldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color.goldPrimary.opacity(0.5), radius: 30)

                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.emerald900)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            }

            Spacer()

            // App name
            VStack(spacing: Spacing.spacing8) {
                Text("WRAPPED")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(8)
                    .foregroundColor(.white)
                    .opacity(logoOpacity)

                Text("Your Year-Round Spotify Story")
                    .font(.bodySmall)
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(logoOpacity)
            }
            .padding(.bottom, 100)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo entrance
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1
            logoOpacity = 1
        }

        // Pulse rings
        for i in 0..<3 {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(Double(i) * 0.4)) {
                pulseRings[i] = true
            }
        }

        // Auto-advance after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            manager.nextStep()
        }
    }
}

// MARK: - Value Intro Screens

struct ValueIntroConfig {
    let icon: String
    let headline: String
    let subheadline: String
    let illustration: ValueIllustration

    enum ValueIllustration {
        case listeningStory
        case patterns
        case privacy
    }

    static let listeningStory = ValueIntroConfig(
        icon: "music.note.list",
        headline: "See Your\nListening Story",
        subheadline: "Track every song, artist, and album.\nYour music journey, beautifully visualized.",
        illustration: .listeningStory
    )

    static let discoverPatterns = ValueIntroConfig(
        icon: "chart.line.uptrend.xyaxis",
        headline: "Discover\nPatterns",
        subheadline: "Find out when you listen most,\nwhat genres define you, and more.",
        illustration: .patterns
    )

    static let privateSecure = ValueIntroConfig(
        icon: "lock.shield.fill",
        headline: "Private.\nSecure. Yours.",
        subheadline: "Your data stays on your device.\nNo ads. No tracking. Just insights.",
        illustration: .privacy
    )
}

struct ValueIntroScreen: View {
    @ObservedObject var manager: OnboardingManager
    let config: ValueIntroConfig

    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var illustrationScale: CGFloat = 0.8

    private var stepIndex: Int {
        switch manager.currentStep {
        case .valueIntro1: return 0
        case .valueIntro2: return 1
        case .valueIntro3: return 2
        default: return 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i <= stepIndex ? Color.goldPrimary : Color.white.opacity(0.3))
                        .frame(width: i == stepIndex ? 24 : 8, height: 8)
                }
            }
            .padding(.top, 60)

            Spacer()

            // Illustration
            ValueIllustrationView(type: config.illustration)
                .frame(height: 200)
                .scaleEffect(illustrationScale)
                .opacity(contentOpacity)

            Spacer()

            // Content
            VStack(spacing: Spacing.spacing20) {
                Image(systemName: config.icon)
                    .font(.system(size: 40))
                    .foregroundColor(.goldPrimary)

                Text(config.headline)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(config.subheadline)
                    .font(.bodyDefault)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Spacing.spacing32)
            .opacity(contentOpacity)
            .offset(y: contentOffset)

            Spacer()

            // Continue button
            PremiumButton(
                title: manager.currentStep == .valueIntro3 ? "Get Started" : "Continue",
                style: .primary
            ) {
                manager.nextStep()
            }
            .padding(.horizontal, Spacing.spacing24)
            .padding(.bottom, 50)
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                contentOpacity = 1
                contentOffset = 0
                illustrationScale = 1
            }
        }
        .onDisappear {
            contentOpacity = 0
            contentOffset = 30
            illustrationScale = 0.8
        }
    }
}

struct ValueIllustrationView: View {
    let type: ValueIntroConfig.ValueIllustration
    @State private var animate = false

    var body: some View {
        ZStack {
            switch type {
            case .listeningStory:
                // Animated waveform bars
                HStack(spacing: 6) {
                    ForEach(0..<9, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.goldPrimary, Color.goldLight.opacity(0.6)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 12, height: animate ? CGFloat.random(in: 40...120) : 60)
                            .animation(
                                .easeInOut(duration: Double.random(in: 0.5...1.0))
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.1),
                                value: animate
                            )
                    }
                }

            case .patterns:
                // Animated chart line
                ZStack {
                    // Grid lines
                    VStack(spacing: 20) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                        }
                    }

                    // Chart line
                    ChartLineShape(animate: animate)
                        .stroke(
                            LinearGradient(
                                colors: [Color.goldPrimary, Color.emerald400],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.goldPrimary.opacity(0.5), radius: 8)
                }
                .frame(width: 200, height: 100)

            case .privacy:
                // Animated shield with lock
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(Color.goldPrimary.opacity(0.1))
                        .frame(width: 160, height: 160)
                        .scaleEffect(animate ? 1.2 : 1)
                        .opacity(animate ? 0.3 : 0.8)

                    // Shield
                    Image(systemName: "shield.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.goldPrimary, Color.goldLight],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Lock
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.emerald900)
                        .offset(y: 5)
                }
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ChartLineShape: Shape {
    var animate: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [CGPoint] = [
            CGPoint(x: 0, y: rect.height * 0.7),
            CGPoint(x: rect.width * 0.2, y: rect.height * 0.5),
            CGPoint(x: rect.width * 0.4, y: rect.height * 0.8),
            CGPoint(x: rect.width * 0.6, y: rect.height * 0.3),
            CGPoint(x: rect.width * 0.8, y: rect.height * 0.5),
            CGPoint(x: rect.width, y: rect.height * 0.2)
        ]

        path.move(to: points[0])
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let control1 = CGPoint(x: prev.x + (curr.x - prev.x) / 2, y: prev.y)
            let control2 = CGPoint(x: prev.x + (curr.x - prev.x) / 2, y: curr.y)
            path.addCurve(to: curr, control1: control1, control2: control2)
        }

        return path
    }
}

// MARK: - Spotify Login Screen

struct SpotifyLoginScreen: View {
    @ObservedObject var manager: OnboardingManager
    @StateObject private var authViewModel = AuthViewModel()
    private let appState = AppState.shared

    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: Spacing.spacing32) {
            Spacer()

            // Spotify icon with glow
            ZStack {
                Circle()
                    .fill(Color(hex: "1DB954").opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)

                Circle()
                    .fill(Color(hex: "1DB954"))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color(hex: "1DB954").opacity(0.5), radius: 20)

                Image(systemName: "music.note")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            VStack(spacing: Spacing.spacing16) {
                Text("Connect Spotify")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("We need access to your listening history\nto show you personalized insights")
                    .font(.bodyDefault)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // What we access
            VStack(alignment: .leading, spacing: Spacing.spacing12) {
                PermissionRow(icon: "clock.fill", text: "Recently played tracks")
                PermissionRow(icon: "music.mic", text: "Your top artists & songs")
                PermissionRow(icon: "person.fill", text: "Basic profile info")
            }
            .padding(Spacing.spacing20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(Radius.large)
            .padding(.horizontal, Spacing.spacing24)

            Spacer()

            // Connect button
            VStack(spacing: Spacing.spacing16) {
                PremiumButton(
                    title: authViewModel.isAuthenticating ? "Connecting..." : "Connect with Spotify",
                    icon: "link",
                    style: .spotify,
                    isLoading: authViewModel.isAuthenticating
                ) {
                    Task {
                        await authViewModel.startLogin()
                    }
                }

                Button(action: {
                    // Skip for now - go to next step with limited functionality
                    manager.goToStep(.permissionExplain)
                }) {
                    Text("Maybe later")
                        .font(.bodySmall)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, Spacing.spacing24)
            .padding(.bottom, 50)
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
        .alert("Connection Error", isPresented: $authViewModel.showError) {
            Button("Try Again") {
                Task { await authViewModel.startLogin() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(authViewModel.errorMessage ?? "Unknown error")
        }
        .onReceive(appState.$isAuthenticated) { isAuthenticated in
            print("🔑 SpotifyLoginScreen: Auth changed to \(isAuthenticated)")
            if isAuthenticated {
                print("✅ SpotifyLoginScreen: Moving to permission screen")
                manager.goToStep(.permissionExplain)
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.spacing12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.goldPrimary)

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24)

            Text(text)
                .font(.bodySmall)
                .foregroundColor(.white.opacity(0.8))

            Spacer()
        }
    }
}

// MARK: - Permission Explanation Screen

struct PermissionScreen: View {
    @ObservedObject var manager: OnboardingManager
    @State private var contentOpacity: Double = 0
    @State private var showItems = false

    let permissions = [
        PermissionItem(
            icon: "music.note.list",
            title: "Listening History",
            description: "See what you've been playing"
        ),
        PermissionItem(
            icon: "chart.bar.fill",
            title: "Playback Stats",
            description: "Track patterns & trends"
        ),
        PermissionItem(
            icon: "person.crop.circle",
            title: "Profile Info",
            description: "Personalize your experience"
        )
    ]

    var body: some View {
        VStack(spacing: Spacing.spacing24) {
            Spacer()

            // Header
            VStack(spacing: Spacing.spacing12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.goldPrimary)

                Text("Your Data,\nYour Control")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Here's exactly what we access")
                    .font(.bodyDefault)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Permission items
            VStack(spacing: Spacing.spacing16) {
                ForEach(Array(permissions.enumerated()), id: \.element.title) { index, item in
                    PermissionItemRow(item: item)
                        .opacity(showItems ? 1 : 0)
                        .offset(x: showItems ? 0 : -30)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: showItems
                        )
                }
            }
            .padding(.horizontal, Spacing.spacing24)

            // Privacy note
            HStack(spacing: Spacing.spacing8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                Text("We never share or sell your data")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.5))
            .padding(.top, Spacing.spacing16)

            Spacer()

            // Continue
            PremiumButton(title: "Continue", style: .primary) {
                manager.goToStep(.initialSync)
                manager.startSync()
            }
            .padding(.horizontal, Spacing.spacing24)
            .padding(.bottom, 50)
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                showItems = true
            }
        }
    }
}

struct PermissionItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct PermissionItemRow: View {
    let item: PermissionItem

    var body: some View {
        HStack(spacing: Spacing.spacing16) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.medium)
                    .fill(Color.goldPrimary.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: item.icon)
                    .font(.system(size: 22))
                    .foregroundColor(.goldPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.h3)
                    .foregroundColor(.white)

                Text(item.description)
                    .font(.bodySmall)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.emerald400)
        }
        .padding(Spacing.spacing16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(Radius.large)
    }
}

// MARK: - Initial Sync Screen

struct SyncScreen: View {
    @ObservedObject var manager: OnboardingManager
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        VStack(spacing: Spacing.spacing32) {
            Spacer()

            // Animated sync visualization
            ZStack {
                // Animated circular waves
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.goldPrimary.opacity(0.2), lineWidth: 2)
                        .frame(width: 150 + CGFloat(i * 40), height: 150 + CGFloat(i * 40))
                        .scaleEffect(manager.isSyncing ? 1.2 : 1)
                        .opacity(manager.isSyncing ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 1.5)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.3),
                            value: manager.isSyncing
                        )
                }

                // Center progress circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: manager.syncProgress)
                        .stroke(
                            LinearGradient(
                                colors: [Color.goldPrimary, Color.emerald400],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: manager.syncProgress)

                    // Progress percentage
                    Text("\(Int(manager.syncProgress * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            // Status text
            VStack(spacing: Spacing.spacing12) {
                Text(manager.syncComplete ? "All Set!" : "Syncing Your Music")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text(manager.syncStatus)
                    .font(.bodyDefault)
                    .foregroundColor(.white.opacity(0.6))
                    .animation(.easeInOut, value: manager.syncStatus)
            }

            Spacer()

            // Continue button (appears when complete)
            if manager.syncComplete {
                PremiumButton(title: "Continue", style: .primary) {
                    manager.nextStep()
                }
                .padding(.horizontal, Spacing.spacing24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
                .frame(height: 50)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: manager.syncComplete)
    }
}

// MARK: - Personalization Screen

struct PersonalizationScreen: View {
    @ObservedObject var manager: OnboardingManager
    @State private var contentOpacity: Double = 0

    let genres = ["Pop", "Hip-Hop", "Rock", "Electronic", "R&B", "Indie", "Classical", "Jazz", "Country", "Latin"]

    var body: some View {
        VStack(spacing: Spacing.spacing24) {
            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    manager.nextStep()
                }
                .font(.bodySmall)
                .foregroundColor(.white.opacity(0.6))
                .padding(.trailing, Spacing.spacing24)
            }
            .padding(.top, 60)

            // Header
            VStack(spacing: Spacing.spacing12) {
                Text("Almost there!")
                    .font(.bodyDefault)
                    .foregroundColor(.goldPrimary)

                Text("Personalize\nYour Experience")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Genre selection
            VStack(alignment: .leading, spacing: Spacing.spacing16) {
                Text("Favorite Genres")
                    .font(.h3)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.spacing24)

                GenreSelectionGrid(
                    genres: genres,
                    selectedGenres: $manager.selectedGenres
                )
                .padding(.horizontal, Spacing.spacing24)
            }

            Spacer()

            // Notifications toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Insights")
                        .font(.h3)
                        .foregroundColor(.white)

                    Text("Get notified about your listening stats")
                        .font(.bodySmall)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Toggle("", isOn: $manager.notificationsEnabled)
                    .tint(Color.goldPrimary)
            }
            .padding(Spacing.spacing20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(Radius.large)
            .padding(.horizontal, Spacing.spacing24)

            Spacer()

            // Continue button
            PremiumButton(title: "Continue", style: .primary) {
                manager.nextStep()
            }
            .padding(.horizontal, Spacing.spacing24)
            .padding(.bottom, 50)
        }
        .opacity(contentOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }
}

struct GenreChip: View {
    let genre: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptic.selection()
            action()
        }) {
            Text(genre)
                .font(.bodySmall)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .emerald900 : .white)
                .padding(.horizontal, Spacing.spacing16)
                .padding(.vertical, Spacing.spacing12)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.goldPrimary : Color.white.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.goldPrimary : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .scaleEffect(isSelected ? 1.05 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// Simple wrapping layout for genres (iOS 15+ compatible)
struct GenreSelectionGrid: View {
    let genres: [String]
    @Binding var selectedGenres: Set<String>

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(genres, id: \.self) { genre in
                GenreChip(
                    genre: genre,
                    isSelected: selectedGenres.contains(genre)
                ) {
                    if selectedGenres.contains(genre) {
                        selectedGenres.remove(genre)
                    } else {
                        selectedGenres.insert(genre)
                    }
                }
            }
        }
    }
}

// MARK: - Welcome Screen

struct WelcomeScreen: View {
    @ObservedObject var manager: OnboardingManager
    var onComplete: () -> Void

    @State private var contentOpacity: Double = 0
    @State private var showConfetti = false
    @State private var cardScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            VStack(spacing: Spacing.spacing32) {
                Spacer()

                // Celebration icon
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 20))
                            .foregroundColor(.goldPrimary)
                            .offset(
                                x: showConfetti ? CGFloat.random(in: -60...60) : 0,
                                y: showConfetti ? CGFloat.random(in: -60...60) : 0
                            )
                            .opacity(showConfetti ? 1 : 0)
                            .animation(
                                .spring(response: 0.8, dampingFraction: 0.6)
                                .delay(Double(i) * 0.1),
                                value: showConfetti
                            )
                    }

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.goldPrimary, Color.goldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.goldPrimary.opacity(0.5), radius: 20)
                }

                VStack(spacing: Spacing.spacing12) {
                    Text("You're All Set!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Welcome to your personal\nmusic insights dashboard")
                        .font(.bodyDefault)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Preview card with real data
                VStack(spacing: Spacing.spacing16) {
                    // Top artist preview
                    if let topArtist = manager.previewArtist {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Top Artist")
                                    .font(.caption)
                                    .foregroundColor(.goldPrimary)

                                Text(topArtist)
                                    .font(.h2)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .fill(Color.goldPrimary.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.goldPrimary)
                            }
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))
                    }

                    // Track count
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(manager.previewTrackCount > 0 ? "\(manager.previewTrackCount) tracks" : "Ready to explore")
                                .font(.h3)
                                .foregroundColor(.white)

                            Text(manager.previewTrackCount > 0 ? "analyzed this week" : "your music journey")
                                .font(.bodySmall)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "music.note.list")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(Spacing.spacing24)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(Radius.xLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xLarge)
                        .stroke(Color.goldPrimary.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, Spacing.spacing24)
                .scaleEffect(cardScale)

                Spacer()

                // Start exploring button
                PremiumButton(
                    title: "Start Exploring",
                    icon: "arrow.right",
                    style: .primary
                ) {
                    onComplete()
                }
                .padding(.horizontal, Spacing.spacing24)
                .padding(.bottom, 50)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                contentOpacity = 1
                cardScale = 1
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                showConfetti = true
            }
        }
    }
}

// MARK: - Premium Button Component

enum PremiumButtonStyle {
    case primary
    case secondary
    case spotify
}

struct PremiumButton: View {
    let title: String
    var icon: String? = nil
    let style: PremiumButtonStyle
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    private var backgroundColor: some View {
        switch style {
        case .primary:
            return AnyView(
                LinearGradient(
                    colors: [Color.goldPrimary, Color.goldLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .secondary:
            return AnyView(Color.white.opacity(0.1))
        case .spotify:
            return AnyView(Color(hex: "1DB954"))
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .emerald900
        case .secondary:
            return .white
        case .spotify:
            return .white
        }
    }

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            Haptic.medium()
            action()
        }) {
            HStack(spacing: Spacing.spacing8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(title)
                        .font(.h3)
                }
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.spacing20)
            .background(backgroundColor)
            .cornerRadius(Radius.large)
            .shadow(
                color: style == .primary ? Color.goldPrimary.opacity(0.4) : Color.clear,
                radius: 16,
                y: 8
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1)
        .disabled(isLoading)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(onComplete: {})
}
