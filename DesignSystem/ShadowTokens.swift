// ShadowTokens.swift
// Design System Shadow/Elevation Tokens
// Generated from token specification

import SwiftUI

// MARK: - Shadow Extensions
extension View {
    /// Standard card elevation shadow
    /// emerald900 @ 4%, 0x 2y 8blur
    func cardShadow() -> some View {
        self.shadow(color: Color.emerald900.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    /// Hero card and elevated elements shadow
    /// emerald900 @ 12%, 0x 8y 24blur
    func heroShadow() -> some View {
        self.shadow(color: Color.emerald900.opacity(0.12), radius: 24, x: 0, y: 8)
    }
    
    /// Floating action button shadow
    /// emerald900 @ 16%, 0x 4y 12blur
    func fabShadow() -> some View {
        self.shadow(color: Color.emerald900.opacity(0.16), radius: 12, x: 0, y: 4)
    }
    
    /// Gold badge/accent glow
    /// goldPrimary @ 20%, 0x 2y 8blur
    func goldGlow() -> some View {
        self.shadow(color: Color.goldPrimary.opacity(0.20), radius: 8, x: 0, y: 2)
    }
}
