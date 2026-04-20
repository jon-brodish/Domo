import SwiftUI

struct InsightBadge: View {
    var title: String
    var value: String
    var symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(style.accent)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(style.iconBackground)
                    )

                Spacer(minLength: 8)

                Text(style.chipLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.06))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.primary.opacity(0.92))
                    .contentTransition(.numericText())
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(Color.primary.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(style.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.primary.opacity(0.60))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.topFill, style.bottomFill],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style.stroke, lineWidth: 1)
        )
        .shadow(color: style.shadow, radius: 12, x: 0, y: 7)
    }

    private var style: BadgeStyle {
        switch title.lowercased() {
        case "overdue":
            return BadgeStyle(
                accent: .orange,
                topFill: Color.orange.opacity(0.24),
                bottomFill: Color.red.opacity(0.12),
                iconBackground: Color.orange.opacity(0.18),
                stroke: Color.white.opacity(0.36),
                shadow: Color.black.opacity(0.14),
                chipLabel: "Priority",
                subtitle: "Past due and needs action"
            )
        case "completed":
            return BadgeStyle(
                accent: .green,
                topFill: Color.green.opacity(0.22),
                bottomFill: Color.mint.opacity(0.12),
                iconBackground: Color.green.opacity(0.18),
                stroke: Color.white.opacity(0.34),
                shadow: Color.black.opacity(0.12),
                chipLabel: "On Track",
                subtitle: "Finished in recent activity"
            )
        default:
            return BadgeStyle(
                accent: .blue,
                topFill: Color.blue.opacity(0.20),
                bottomFill: Color.cyan.opacity(0.10),
                iconBackground: Color.blue.opacity(0.17),
                stroke: Color.white.opacity(0.33),
                shadow: Color.black.opacity(0.12),
                chipLabel: "Upcoming",
                subtitle: "Coming up in the next week"
            )
        }
    }
}

private struct BadgeStyle {
    let accent: Color
    let topFill: Color
    let bottomFill: Color
    let iconBackground: Color
    let stroke: Color
    let shadow: Color
    let chipLabel: String
    let subtitle: String
}
