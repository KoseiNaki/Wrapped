import SwiftUI
import UIKit

// MARK: - AppTheme Compatibility Layer
// This provides backward compatibility for existing views
// All new code should use the token names directly (e.g., Color.emerald900, Font.h1)
struct AppTheme {
    // Map old names to new tokens for backward compatibility
    static let emeraldDarkest = Color.emerald900
    static let emeraldDark = Color.emerald800
    static let emeraldBase = Color.emerald700
    static let emeraldMid = Color.emerald600
    static let emeraldLight = Color.emerald500
    static let emeraldMuted = Color.emerald400
    
    static let goldMetallic = Color.goldPrimary
    static let goldHighlight = Color.goldLight
    static let goldSubtle = Color.goldMuted
    
    static let backgroundPrimary = Color.bgPrimary
    static let backgroundSecondary = Color.bgSecondary
    static let backgroundElevated = Color.surfaceCardElevated
    
    static let cardBackground = Color.surfaceCard
    static let cardBackgroundLight = Color.emerald50
    static let cardBackgroundEmerald = Color.emerald800.opacity(0.95)
    
    static let textPrimary = Color.textPrimary
    static let textSecondary = Color.textSecondary
    static let textTertiary = Color.textTertiary
    static let textOnEmerald = Color.textOnDark
    static let textOnGold = Color.textPrimary  // emerald900 on gold
    
    // Legacy naming
    static let background = Color.bgPrimary
    static let gold = Color.goldPrimary
    static let goldLight = Color.goldLight
    
    static let divider = Color.borderDefault
    static let cardBorder = Color.borderDefault
}

// MARK: - Legacy Theme (for compatibility)
struct Theme {
    static let shared = Theme()

    struct Colors {
        static let lightBackground = Color(hex: "FFFFFF")
        static let lightSurface = Color(hex: "F8F8F8")
        static let lightSurfaceElevated = Color.white
        static let lightPrimaryText = Color(hex: "0A0A0A")
        static let lightSecondaryText = Color(hex: "6B6B6B")
        static let lightTertiaryText = Color(hex: "A8A8A8")
        static let lightAccent = Color(hex: "E3B74D") // Gold
        static let lightAccentSubtle = Color(hex: "2A2418")
        static let lightSeparator = Color(hex: "E5E5E5")
        static let lightError = Color(hex: "FF3B30")
        static let lightWarning = Color(hex: "FF9500")

        static let darkBackground = Color.black
        static let darkSurface = Color(hex: "1C1C1C")
        static let darkSurfaceElevated = Color(hex: "242424")
        static let darkPrimaryText = Color.white
        static let darkSecondaryText = Color(hex: "8C8C8C")
        static let darkTertiaryText = Color(hex: "666666")
        static let darkAccent = Color(hex: "E3B74D") // Gold
        static let darkAccentSubtle = Color(hex: "2A2418")
        static let darkSeparator = Color(hex: "333333")
        static let darkError = Color(hex: "FF453A")
        static let darkWarning = Color(hex: "FF9F0A")

        static let background = darkBackground
        static let surface = darkSurface
        static let surfaceElevated = darkSurfaceElevated
        static let primaryText = darkPrimaryText
        static let secondaryText = darkSecondaryText
        static let tertiaryText = darkTertiaryText
        static let accent = darkAccent
        static let accentSubtle = darkAccentSubtle
        static let separator = darkSeparator
        static let error = darkError
        static let warning = darkWarning
    }

    struct Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 20
    }

    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title1 = Font.system(size: 28, weight: .semibold)
        static let title2 = Font.system(size: 22, weight: .semibold)
        static let title3 = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17)
        static let callout = Font.system(size: 16)
        static let subheadline = Font.system(size: 15)
        static let footnote = Font.system(size: 13)
        static let caption1 = Font.system(size: 12)
        static let caption2 = Font.system(size: 11, weight: .medium)
        static let buttonLabel = Font.system(size: 17, weight: .semibold)
    }

    struct Shadow {
        static func level1(colorScheme: ColorScheme) -> ShadowStyle {
            ShadowStyle(color: .black.opacity(0.3), radius: 12, y: 4)
        }

        static func level2(colorScheme: ColorScheme) -> ShadowStyle {
            ShadowStyle(color: .black.opacity(0.5), radius: 20, y: 6)
        }

        static func level3(colorScheme: ColorScheme) -> ShadowStyle {
            ShadowStyle(color: .black.opacity(0.7), radius: 32, y: 10)
        }
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

// MARK: - Color Hex Initializer moved to ColorTokens.swift
// The Color(hex:) initializer is now defined in ColorTokens.swift

extension Color {
    init(_ name: String, light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

extension View {
    func luxuryShadow(level: Int = 1, colorScheme: ColorScheme) -> some View {
        let shadow: ShadowStyle
        switch level {
        case 2:
            shadow = Theme.Shadow.level2(colorScheme: colorScheme)
        case 3:
            shadow = Theme.Shadow.level3(colorScheme: colorScheme)
        default:
            shadow = Theme.Shadow.level1(colorScheme: colorScheme)
        }

        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Premium Card Modifier

struct PremiumCardModifier: ViewModifier {
    var padding: CGFloat = Spacing.spacing20
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.large)
                        .fill(Color.surfaceCard)
                    
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), Color.borderDefault.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.emerald900.opacity(0.06), radius: 12, x: 0, y: 4)
            .shadow(color: Color.emerald900.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func premiumCard(padding: CGFloat = Spacing.spacing20) -> some View {
        modifier(PremiumCardModifier(padding: padding))
    }
}

// MARK: - Shimmer Loading View

struct ShimmerView: View {
    @State private var phase: CGFloat = -1
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = Radius.small
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.emerald50)
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.emerald50.opacity(0.3),
                            Color.emerald100.opacity(0.6),
                            Color.emerald50.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: geo.size.width * phase)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

struct ShimmerRow: View {
    var body: some View {
        HStack(spacing: Spacing.spacing12) {
            ShimmerView(height: 52, cornerRadius: Radius.medium)
                .frame(width: 52)
            
            VStack(alignment: .leading, spacing: 6) {
                ShimmerView(width: 140, height: 14)
                ShimmerView(width: 90, height: 12)
            }
            
            Spacer()
            
            ShimmerView(width: 40, height: 14)
        }
        .padding(.vertical, Spacing.spacing8)
    }
}

// MARK: - Reusable Components

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.h2)
                .foregroundColor(.emerald900)

            Spacer()

            if let trailing = trailing {
                Button(action: { trailingAction?() }) {
                    HStack(spacing: 4) {
                        Text(trailing)
                            .font(.bodySmall)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.goldPrimary)
                }
            }
        }
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let sublabel: String?
    var onTap: (() -> Void)? = nil
    @State private var appeared = false
    @State private var isPressed = false

    init(icon: String, value: String, label: String, sublabel: String? = nil, onTap: (() -> Void)? = nil) {
        self.icon = icon
        self.value = value
        self.label = label
        self.sublabel = sublabel
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.spacing12) {
            // Icon + chevron row
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.emerald50)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.emerald600)
                }
                
                Spacer()
                
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.goldPrimary.opacity(0.6))
                }
            }

            Spacer()

            // Value
            Text(value)
                .font(.statValue)
                .foregroundColor(.emerald900)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Label
            VStack(alignment: .leading, spacing: Spacing.spacing4) {
                Text(label)
                    .font(.labelSmall)
                    .foregroundColor(.textSecondary)
                    .trackedLabel(1.0)
                    .lineLimit(1)

                if let sublabel = sublabel {
                    Text(sublabel)
                        .font(.caption)
                        .foregroundColor(.goldPrimary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.spacing20)
        .frame(height: 160)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Radius.large)
                    .fill(Color.surfaceCard)
                
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.8),
                        Color.white.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.large))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.large)
                .strokeBorder(Color.borderDefault.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.emerald900.opacity(0.06), radius: 12, x: 0, y: 4)
        .shadow(color: Color.emerald900.opacity(0.04), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.96 : (appeared ? 1 : 0.8))
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .onTapGesture {
            guard let onTap = onTap else { return }
            Haptic.light()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
                onTap()
            }
        }
    }
}

struct TrackRow: View {
    let rank: Int?
    let imageUrl: String?
    let title: String
    let subtitle: String
    let trailing: String
    let trailingLabel: String?
    var showPlayButton: Bool = false
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: Spacing.spacing12) {
            // Rank number with medal colors for top 3
            if let rank = rank {
                ZStack {
                    if rank <= 3 {
                        Circle()
                            .fill(rankColor(rank))
                            .frame(width: 28, height: 28)
                        Text("\(rank)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(rank == 1 ? .emerald900 : .white)
                    } else {
                        Text("\(rank)")
                            .font(.rankNumber)
                            .foregroundColor(.emerald500)
                    }
                }
                .frame(width: 28)
            }

            // Album art / Image
            ZStack {
                if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.emerald50)
                    }
                } else {
                    Rectangle()
                        .fill(Color.emerald50)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(.emerald400)
                        )
                }

                if showPlayButton {
                    Circle()
                        .fill(Color.emerald800.opacity(0.9))
                        .frame(width: 26, height: 26)
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.goldPrimary)
                }
            }
            .frame(width: 52, height: 52)
            .cornerRadius(Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.medium)
                    .stroke(Color.borderDefault.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: Color.emerald900.opacity(0.06), radius: 4, x: 0, y: 2)

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.bodyDefault)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.spacing8)

            // Trailing value
            VStack(alignment: .trailing, spacing: 2) {
                Text(trailing)
                    .font(.captionBold)
                    .foregroundColor(trailingLabel != nil ? .goldPrimary : .textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)

                if let label = trailingLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, Spacing.spacing8)
        .padding(.horizontal, isHighlighted ? Spacing.spacing12 : 0)
        .background(
            isHighlighted
                ? HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.goldPrimary)
                        .frame(width: 3)
                    Color.emerald50
                }
                .cornerRadius(Radius.medium)
                .eraseToAnyView()
                : Color.clear.eraseToAnyView()
        )
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.goldPrimary
        case 2: return Color(hex: "A8A8A8") // silver
        case 3: return Color(hex: "CD7F32") // bronze
        default: return Color.emerald50
        }
    }
}

// Helper to erase view types in ternary
extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

struct PeriodPicker: View {
    @Binding var selection: String
    let options: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    Text(option)
                        .font(.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(selection == option ? .textPrimary : .textSecondary)
                        .padding(.horizontal, Spacing.spacing20)
                        .padding(.vertical, Spacing.spacing12)
                        .background(
                            selection == option
                                ? Color.goldPrimary
                                : Color.clear
                        )
                        .cornerRadius(Radius.full)
                }
            }
        }
        .padding(4)
        .background(Color.bgSecondary)
        .cornerRadius(24)
    }
}

func getGreeting() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12: return "Good morning"
    case 12..<17: return "Good afternoon"
    default: return "Good evening"
    }
}

// MARK: - Haptic Manager

enum Haptic {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
