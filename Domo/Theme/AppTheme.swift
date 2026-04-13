import SwiftUI

enum AppTheme {
    static var background: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(uiColor: .systemGroupedBackground)
#endif
    }

    static let cardGradient = LinearGradient(
        colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let healthExcellent = Color.green
    static let healthGood = Color.mint
    static let healthWarning = Color.orange
    static let healthPoor = Color.red

    static let shadow = Color.black.opacity(0.08)
}
