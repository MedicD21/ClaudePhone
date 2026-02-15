import SwiftUI

// MARK: - ClaudePhone Design System
struct AppTheme {
    // Primary palette
    static let primary = Color(hex: "579cc3")
    static let accent = Color(hex: "f2a047")
    static let success = Color(hex: "7fb069")
    static let error = Color(hex: "e05555")
    static let warning = Color(hex: "e0a83d")

    // Background hierarchy
    static let backgroundPrimary = Color(hex: "0d1117")
    static let backgroundSecondary = Color(hex: "161b22")
    static let backgroundTertiary = Color(hex: "1c2333")
    static let backgroundElevated = Color(hex: "21283b")

    // Text hierarchy
    static let textPrimary = Color(hex: "e6edf3")
    static let textSecondary = Color(hex: "8b949e")
    static let textTertiary = Color(hex: "6e7681")

    // Glassmorphism
    static let glassFill = Color.white.opacity(0.06)
    static let glassBorder = Color.white.opacity(0.1)
    static let glassHighlight = Color.white.opacity(0.15)

    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [primary, primary.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accent, accent.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [backgroundPrimary, backgroundSecondary],
        startPoint: .top,
        endPoint: .bottom
    )

    // Corner radii
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusXL: CGFloat = 20
    static let radiusRound: CGFloat = 50

    // Shadows
    static let shadowColor = Color.black.opacity(0.3)
    static let shadowRadius: CGFloat = 10
    static let shadowY: CGFloat = 4

    // Animation
    static let springAnimation = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let quickAnimation = Animation.easeInOut(duration: 0.2)
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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

// MARK: - Glass Morphism Modifier
struct GlassMorphismModifier: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.radiusMedium

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.glassFill)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.glassBorder, lineWidth: 1)
            )
    }
}

// MARK: - Card Modifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .fill(AppTheme.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(AppTheme.glassBorder, lineWidth: 0.5)
            )
            .shadow(color: AppTheme.shadowColor, radius: AppTheme.shadowRadius / 2, y: AppTheme.shadowY / 2)
    }
}

// MARK: - View Extensions
extension View {
    func glassMorphism(cornerRadius: CGFloat = AppTheme.radiusMedium) -> some View {
        modifier(GlassMorphismModifier(cornerRadius: cornerRadius))
    }

    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func shimmer(isActive: Bool = true) -> some View {
        self.overlay(
            GeometryReader { geometry in
                if isActive {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.1), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width)
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isActive
                    )
                }
            }
            .clipped()
        )
    }
}
