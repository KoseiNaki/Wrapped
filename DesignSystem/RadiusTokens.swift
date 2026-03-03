// RadiusTokens.swift
// Design System Corner Radius Tokens
// Generated from token specification

import SwiftUI

// MARK: - Corner Radius Scale
enum Radius {
    /// 8pt - Badges, small buttons, segment pills
    static let small: CGFloat = 8
    
    /// 12pt - Cards, inputs, list rows
    static let medium: CGFloat = 12
    
    /// 16pt - Hero cards, modal sheets, large cards
    static let large: CGFloat = 16
    
    /// 20pt - Album art images, profile avatars
    static let xLarge: CGFloat = 20
    
    /// 999pt - Circular elements (FAB, profile circle)
    static let full: CGFloat = 999
}
