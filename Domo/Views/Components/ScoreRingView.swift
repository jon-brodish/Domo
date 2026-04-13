import SwiftUI

struct ScoreRingView: View {
    var score: Int
    var band: HealthBand
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 9)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    band.color,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                Text("health")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Health score \(score)")
    }
}
