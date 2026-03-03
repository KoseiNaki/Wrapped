// File: Views/LoginView.swift
import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var iconOffset: CGFloat = 0
    @State private var titleAppeared = false
    @State private var buttonAppeared = false
    
    var body: some View {
        ZStack {
            // Animated emerald gradient
            LinearGradient(
                colors: [
                    Color.emerald800,
                    Color.emerald900,
                    Color(hex: "0A3622")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle pattern overlay
            GeometryReader { geo in
                Circle()
                    .fill(Color.emerald700.opacity(0.15))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 60)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)
                
                Circle()
                    .fill(Color.goldPrimary.opacity(0.06))
                    .frame(width: geo.size.width * 0.6)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.5)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Icon + Title
                VStack(spacing: Spacing.spacing24) {
                    // Floating waveform icon
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.goldPrimary, Color.goldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.goldPrimary.opacity(0.3), radius: 24, x: 0, y: 12)
                        .offset(y: iconOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                                iconOffset = -10
                            }
                        }
                    
                    VStack(spacing: Spacing.spacing8) {
                        Text("Wrapped")
                            .font(.system(size: 40, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        
                        Text("Your Spotify story, beautifully told")
                            .font(.bodyDefault)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 15)
                }
                
                Spacer()
                Spacer()
                
                // Bottom CTA
                VStack(spacing: Spacing.spacing16) {
                    Button {
                        Haptic.medium()
                        Task { await viewModel.startLogin() }
                    } label: {
                        HStack(spacing: Spacing.spacing12) {
                            if viewModel.isAuthenticating {
                                ProgressView()
                                    .tint(Color.emerald900)
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Connect with Spotify")
                                    .font(.h3)
                            }
                        }
                        .foregroundColor(.emerald900)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.goldPrimary)
                        .cornerRadius(Radius.large)
                    }
                    .goldGlow()
                    .scaleEffect(buttonAppeared ? 1 : 0.9)
                    .disabled(viewModel.isAuthenticating)
                    
                    HStack(spacing: Spacing.spacing4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 11))
                        Text("Privacy-first. We never post without permission.")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, Spacing.spacing32)
                .padding(.bottom, Spacing.spacing40)
                .opacity(buttonAppeared ? 1 : 0)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) { titleAppeared = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) { buttonAppeared = true }
        }
        .alert("Authentication Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
