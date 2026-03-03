import SwiftUI

// MARK: - Primary Button (Emerald background, white text)
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.h3)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isEnabled ? Color.emerald700 : Color.textTertiary)
            .cornerRadius(Radius.large)
            .shadow(color: Color.emerald700.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button (Outlined with emerald)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.h3)
            .foregroundColor(.emerald700)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large)
                    .stroke(Color.emerald700, lineWidth: 2)
            )
            .cornerRadius(Radius.large)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Tertiary Button (Text only)
struct TertiaryButtonStyle: ButtonStyle {
    var color: Color = .emerald700
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.h3)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button (Red background)
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.h3)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.destructive)
            .cornerRadius(Radius.large)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
