import SwiftUI

enum AppTheme {
    static var background: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(uiColor: .secondarySystemBackground)
#endif
    }

    static let shellTop = Color(red: 0.61, green: 0.76, blue: 0.91)
    static let shellBottom = Color(red: 0.93, green: 0.82, blue: 0.67)
    static let shellMid = Color(red: 0.74, green: 0.83, blue: 0.91)
    static let shellMist = Color(red: 0.82, green: 0.87, blue: 0.94)

    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.56), Color.white.opacity(0.24)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let healthExcellent = Color.green
    static let healthGood = Color.mint
    static let healthWarning = Color.orange
    static let healthPoor = Color.red

    static let shadow = Color.black.opacity(0.08)
}

struct AmbientBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.shellTop, AppTheme.shellMid, AppTheme.shellBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppTheme.shellMist.opacity(0.50))
                .frame(width: 360, height: 360)
                .blur(radius: 85)
                .offset(x: -130, y: -230)

            Circle()
                .fill(Color.white.opacity(0.40))
                .frame(width: 290, height: 290)
                .blur(radius: 80)
                .offset(x: 160, y: 150)

            LinearGradient(
                colors: [Color.black.opacity(0.16), Color.clear, Color.black.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.25 : 0.34))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(configuration.isPressed ? 0.24 : 0.48),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct AccentCapsuleButtonStyle: ButtonStyle {
    var tint: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(configuration.isPressed ? 0.82 : 0.96),
                                tint.opacity(configuration.isPressed ? 0.60 : 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.34), radius: 9, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
