// DesignSystemPreview.swift
// A quick visual test to verify the design system is working
// To use: Temporarily change WrappedApp to show DesignSystemPreview()

import SwiftUI

struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.spacing24) {
                Text("Design System Visual Test")
                    .font(.displayLarge)
                    .foregroundColor(.textPrimary)
                
                // Color swatches
                VStack(alignment: .leading, spacing: Spacing.spacing16) {
                    Text("COLORS")
                        .font(.label)
                        .foregroundColor(.textSecondary)
                        .trackedLabel()
                    
                    // Emerald scale
                    HStack(spacing: 4) {
                        colorSwatch(Color.emerald900, "900")
                        colorSwatch(Color.emerald800, "800")
                        colorSwatch(Color.emerald700, "700")
                        colorSwatch(Color.emerald600, "600")
                        colorSwatch(Color.emerald500, "500")
                    }
                    
                    // Gold scale
                    HStack(spacing: 4) {
                        colorSwatch(Color.goldPrimary, "Gold")
                        colorSwatch(Color.goldLight, "Light")
                        colorSwatch(Color.goldMuted, "Muted")
                    }
                    
                    // Backgrounds
                    HStack(spacing: 4) {
                        colorSwatch(Color.bgPrimary, "BG")
                        colorSwatch(Color.surfaceCard, "Card")
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(Radius.large)
                .cardShadow()
                
                // Typography
                VStack(alignment: .leading, spacing: Spacing.spacing16) {
                    Text("TYPOGRAPHY")
                        .font(.label)
                        .foregroundColor(.textSecondary)
                        .trackedLabel()
                    
                    Text("Display Large")
                        .font(.displayLarge)
                    
                    Text("Heading 1")
                        .font(.h1)
                    
                    Text("Heading 2")
                        .font(.h2)
                    
                    Text("Body Default")
                        .font(.bodyDefault)
                    
                    Text("Caption text")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Text("Tracked Label")
                        .font(.label)
                        .foregroundColor(.goldPrimary)
                        .trackedLabel()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.surfaceCard)
                .cornerRadius(Radius.large)
                .cardShadow()
                
                // Buttons
                VStack(alignment: .leading, spacing: Spacing.spacing16) {
                    Text("BUTTONS")
                        .font(.label)
                        .foregroundColor(.textSecondary)
                        .trackedLabel()
                    
                    Button("Primary Button") {}
                        .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Secondary Button") {}
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding()
                .background(Color.surfaceCard)
                .cornerRadius(Radius.large)
                .cardShadow()
                
                // Shadows
                VStack(alignment: .leading, spacing: Spacing.spacing16) {
                    Text("SHADOWS")
                        .font(.label)
                        .foregroundColor(.textSecondary)
                        .trackedLabel()
                    
                    Text("Card Shadow")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(Radius.medium)
                        .cardShadow()
                    
                    Text("Hero Shadow")
                        .padding()
                        .background(Color.emerald700)
                        .foregroundColor(.white)
                        .cornerRadius(Radius.medium)
                        .heroShadow()
                    
                    Text("Gold Glow")
                        .padding()
                        .background(Color.goldPrimary)
                        .foregroundColor(.emerald900)
                        .cornerRadius(Radius.medium)
                        .goldGlow()
                }
                .padding()
                .background(Color.surfaceCard)
                .cornerRadius(Radius.large)
                .cardShadow()
                
                Text("✅ If you see emerald greens, warm golds, and beige backgrounds, the design system is working!")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
        .background(Color.bgPrimary)
        .preferredColorScheme(.light)
    }
    
    private func colorSwatch(_ color: Color, _ label: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.borderDefault, lineWidth: 1)
                )
            
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
}

struct DesignSystemPreview_Previews: PreviewProvider {
    static var previews: some View {
        DesignSystemPreview()
    }
}
