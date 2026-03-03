// TypographyTokens.swift
// Design System Typography Tokens
// Generated from token specification

import SwiftUI

// MARK: - Typography Scale
extension Font {
    /// Display large: 34pt Bold (Welcome screen title)
    static let displayLarge = Font.system(size: 34, weight: .bold)
    
    /// H1: 28pt Bold (Screen titles)
    static let h1 = Font.system(size: 28, weight: .bold)
    
    /// H2: 22pt Semibold (Section headers)
    static let h2 = Font.system(size: 22, weight: .semibold)
    
    /// H3: 18pt Semibold (Card titles, hero artist name)
    static let h3 = Font.system(size: 18, weight: .semibold)
    
    /// Label: 13pt Semibold (Uppercase tracked labels)
    static let label = Font.system(size: 13, weight: .semibold)
    
    /// Label Small: 11pt Medium (Uppercase small badges)
    static let labelSmall = Font.system(size: 11, weight: .medium)
    
    /// Body: 16pt Regular (Primary body text)
    static let bodyDefault = Font.system(size: 16, weight: .regular)
    
    /// Body Small: 14pt Regular (Secondary body text)
    static let bodySmall = Font.system(size: 14, weight: .regular)
    
    /// Caption: 12pt Regular (Timestamps, metadata)
    static let caption = Font.system(size: 12, weight: .regular)
    
    /// Caption Bold: 12pt Semibold (Stat values in small contexts)
    static let captionBold = Font.system(size: 12, weight: .semibold)
    
    /// Stat Value: 26pt Bold (Large numbers on stat cards)
    static let statValue = Font.system(size: 26, weight: .bold)
    
    /// Rank Number: 18pt Bold (Rank numbers in lists)
    static let rankNumber = Font.system(size: 18, weight: .bold)
}

// MARK: - Tracked Uppercase Label Modifier
struct TrackedUppercaseLabel: ViewModifier {
    var tracking: CGFloat = 1.5
    
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .textCase(.uppercase)
                .tracking(tracking)
        } else {
            // For iOS 15, just use uppercase without tracking
            content
                .textCase(.uppercase)
        }
    }
}

extension View {
    /// Apply tracked uppercase style to text
    /// - Parameter tracking: Letter spacing (default 1.5pt)
    func trackedLabel(_ tracking: CGFloat = 1.5) -> some View {
        modifier(TrackedUppercaseLabel(tracking: tracking))
    }
}

// MARK: - Typography Usage Examples
#if DEBUG
struct TypographyTokensPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Display Large")
                        .font(.displayLarge)
                    
                    Text("Heading 1")
                        .font(.h1)
                    
                    Text("Heading 2")
                        .font(.h2)
                    
                    Text("Heading 3")
                        .font(.h3)
                    
                    Text("Tracked Label")
                        .font(.label)
                        .trackedLabel()
                    
                    Text("Small Label")
                        .font(.labelSmall)
                        .trackedLabel(1.2)
                }
                
                Group {
                    Text("Body Default - Primary body text at 16pt regular weight for comfortable reading.")
                        .font(.bodyDefault)
                    
                    Text("Body Small - Secondary text at 14pt for descriptions and supporting content.")
                        .font(.bodySmall)
                    
                    Text("Caption text for timestamps")
                        .font(.caption)
                    
                    Text("347")
                        .font(.statValue)
                    
                    Text("1")
                        .font(.rankNumber)
                }
            }
            .padding()
            .foregroundColor(.textPrimary)
        }
        .background(Color.bgPrimary)
    }
}

struct TypographyTokensPreview_Previews: PreviewProvider {
    static var previews: some View {
        TypographyTokensPreview()
    }
}
#endif
