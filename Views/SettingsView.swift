// File: Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var appState = AppState.shared
    @State private var baseURL: String = AppConfig.baseURL
    @State private var useLocalhost = true
    @State private var showSaveAlert = false
    @State private var showLogoutAlert = false
    @AppStorage("weekStartsOnSunday") private var weekStartsOnSunday: Bool = true

    private var weekStartsOnSundayBinding: Binding<Bool> {
        Binding(
            get: { weekStartsOnSunday },
            set: { weekStartsOnSunday = $0 }
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.spacing24) {
                        profileSection
                        statsSummarySection
                        settingsSection
                        logoutSection

                        #if DEBUG
                        debugSection
                        #endif

                        // Version
                        Text("Wrapped v1.0.0")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                            .padding(.top, Spacing.spacing8)
                    }
                    .padding(Spacing.spacing20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.emerald700)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert("Configuration Saved", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("API base URL updated to:\n\(baseURL)")
            }
            .alert("Logout", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    appState.logout()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            let current = AppConfig.baseURL
            useLocalhost = current == AppConfig.localhostURL
            baseURL = current
        }
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: 0) {
            // Gradient header background
            ZStack {
                LinearGradient(
                    colors: [Color.emerald700, Color.emerald900],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 100)
                
                // Profile circle overlapping the gradient
                VStack(spacing: Spacing.spacing12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.emerald600, Color.emerald800],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.emerald900.opacity(0.4), radius: 16, x: 0, y: 8)

                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.goldPrimary)

                        // Crown badge
                        Circle()
                            .fill(Color.goldPrimary)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.emerald900)
                            )
                            .shadow(color: Color.goldPrimary.opacity(0.4), radius: 4, x: 0, y: 2)
                            .offset(x: 34, y: 30)
                    }
                }
                .offset(y: 40)
            }
            
            // Name area (below the gradient)
            VStack(spacing: Spacing.spacing4) {
                Text(appState.currentUser?.displayName ?? "User")
                    .font(.h1)
                    .foregroundColor(.emerald900)

                if let user = appState.currentUser {
                    Text("@\(user.spotifyID)")
                        .font(.bodySmall)
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.top, 56)
            .padding(.bottom, Spacing.spacing16)
        }
        .background(Color.surfaceCard)
        .cornerRadius(Radius.xLarge)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xLarge)
                .strokeBorder(Color.borderDefault.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.emerald900.opacity(0.06), radius: 12, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xLarge))
    }

    // MARK: - Stats Summary
    private var statsSummarySection: some View {
        HStack(spacing: 0) {
            statItem(value: "--", label: "TRACKS", icon: "music.note")
            
            Rectangle()
                .fill(Color.borderDefault.opacity(0.5))
                .frame(width: 1, height: 40)
            
            statItem(value: "--", label: "ALBUMS", icon: "opticaldisc")
            
            Rectangle()
                .fill(Color.borderDefault.opacity(0.5))
                .frame(width: 1, height: 40)
            
            statItem(value: "--", label: "ARTISTS", icon: "person.2")
        }
        .premiumCard(padding: Spacing.spacing16)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Spacing.spacing4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.emerald800)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 0) {
            // Week start
            settingsRow(
                icon: "calendar",
                title: "Week Starts on Sunday",
                control: AnyView(
                    Toggle("", isOn: weekStartsOnSundayBinding)
                        .tint(Color.goldPrimary)
                )
            )
            
            Divider().padding(.leading, 56)
            
            // Environment
            VStack(alignment: .leading, spacing: Spacing.spacing12) {
                HStack {
                    settingsIcon("server.rack")
                    Text("Environment")
                        .font(.bodyDefault)
                        .foregroundColor(.textPrimary)
                    Spacer()
                }

                HStack(spacing: 0) {
                    ForEach([true, false], id: \.self) { isLocal in
                        Button(action: {
                            Haptic.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                useLocalhost = isLocal
                                baseURL = isLocal ? AppConfig.localhostURL : AppConfig.productionURL
                                AppConfig.baseURL = baseURL
                            }
                        }) {
                            Text(isLocal ? "Local" : "Production")
                                .font(.bodySmall)
                                .fontWeight(.semibold)
                                .foregroundColor(useLocalhost == isLocal ? .emerald900 : .textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(useLocalhost == isLocal ? Color.goldPrimary : Color.clear)
                                .cornerRadius(Radius.small)
                        }
                    }
                }
                .padding(4)
                .background(Color.bgSecondary)
                .cornerRadius(Radius.medium)
            }
            .padding(Spacing.spacing16)
        }
        .premiumCard(padding: 0)
    }

    private func settingsRow(icon: String, title: String, control: AnyView) -> some View {
        HStack {
            settingsIcon(icon)
            Text(title)
                .font(.bodyDefault)
                .foregroundColor(.textPrimary)
            Spacer()
            control
        }
        .padding(Spacing.spacing16)
    }
    
    private func settingsIcon(_ name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.emerald50)
                .frame(width: 32, height: 32)
            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.emerald700)
        }
    }

    // MARK: - Debug Section (for testing)
    private var debugSection: some View {
        VStack(spacing: Spacing.spacing12) {
            Text("Debug Options")
                .font(.caption)
                .foregroundColor(.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                Haptic.medium()
                UserDefaults.standard.set(false, forKey: "has_completed_onboarding_v2")
                // Force app to restart state
                appState.logout()
                dismiss()
            }) {
                HStack(spacing: Spacing.spacing8) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                    Text("Reset Onboarding")
                        .font(.bodySmall)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.textSecondary)
                .background(Color.bgSecondary)
                .cornerRadius(Radius.medium)
            }
        }
    }

    // MARK: - Logout
    private var logoutSection: some View {
        Button(action: {
            Haptic.medium()
            showLogoutAlert = true
        }) {
            HStack(spacing: Spacing.spacing8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                Text("Logout")
                    .font(.bodyDefault)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.emerald800)
            .background(Color.emerald50)
            .cornerRadius(Radius.large)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large)
                    .stroke(Color.emerald800.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
