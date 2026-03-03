// ColorTokens.swift
// Design System Color Tokens
// Generated from token specification

import SwiftUI

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Emerald Scale (Primary)
extension Color {
    static let emerald900 = Color(hex: "0A3A2E")
    static let emerald800 = Color(hex: "0F4F3E")
    static let emerald700 = Color(hex: "14694F")
    static let emerald600 = Color(hex: "1A8B66")
    static let emerald500 = Color(hex: "3DA87E")
    static let emerald400 = Color(hex: "5FBE97")
    static let emerald300 = Color(hex: "7BC4AE")
    static let emerald200 = Color(hex: "A8D9C6")
    static let emerald100 = Color(hex: "D4EDE2")
    static let emerald50  = Color(hex: "EDF7F2")
}

// MARK: - Gold Scale (Accent)
extension Color {
    static let goldPrimary = Color(hex: "C9A961")
    static let goldLight   = Color(hex: "D4B976")
    static let goldMuted   = Color(hex: "B89850")
    static let goldSubtle  = Color(hex: "E8D5A3")
}

// MARK: - Background Tokens
extension Color {
    static let bgPrimary   = Color(hex: "F8F6F2")
    static let bgSecondary = Color(hex: "EDE9E0")
    
    /// Card surface with warm white feel (0.97 opacity applied)
    static let surfaceCard = Color.white.opacity(0.97)
    
    /// Elevated card surface (full white)
    static let surfaceCardElevated = Color.white
}

// MARK: - Text Tokens
extension Color {
    static let textPrimary   = Color(hex: "0A3A2E")  // = emerald900
    static let textSecondary = Color(hex: "3D5A4F")
    static let textTertiary  = Color(hex: "7A9488")
    static let textOnDark    = Color(hex: "F8F6F2")
    static let textGold      = Color(hex: "C9A961")  // = goldPrimary
}

// MARK: - Border Tokens
extension Color {
    static let borderDefault = Color(hex: "D4EDE2")  // = emerald100
    static let borderSubtle  = Color(hex: "E8E4DC")
}

// MARK: - Semantic Colors
extension Color {
    static let destructive      = Color(hex: "C0392B")
    static let destructiveLight = Color(hex: "FADBD8")
}

// MARK: - Usage Example & Validation
#if DEBUG
struct ColorTokensPreview: View {
    var body: some View {
        VStack(spacing: 16) {
            // Background example
            VStack(spacing: 8) {
                Text("Color Tokens")
                    .font(.h1)
                    .foregroundColor(.textPrimary)
                
                Text("Design system implementation")
                    .font(.bodyDefault)
                    .foregroundColor(.textSecondary)
                
                Text("Supplementary caption")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.surfaceCard)
            .cornerRadius(12)
            
            // Emerald scale
            HStack(spacing: 4) {
                ForEach([Color.emerald900, .emerald800, .emerald700, .emerald600, .emerald500, .emerald400, .emerald300, .emerald200, .emerald100, .emerald50], id: \.self) { color in
                    Rectangle()
                        .fill(color)
                        .frame(width: 30, height: 60)
                }
            }
            
            // Gold scale
            HStack(spacing: 4) {
                Rectangle().fill(Color.goldPrimary).frame(width: 60, height: 40)
                Rectangle().fill(Color.goldLight).frame(width: 60, height: 40)
                Rectangle().fill(Color.goldMuted).frame(width: 60, height: 40)
                Rectangle().fill(Color.goldSubtle).frame(width: 60, height: 40)
            }
        }
        .padding()
        .background(Color.bgPrimary)
    }
}

struct ColorTokensPreview_Previews: PreviewProvider {
    static var previews: some View {
        ColorTokensPreview()
    }
}
#endif
