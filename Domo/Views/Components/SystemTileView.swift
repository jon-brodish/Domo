import SwiftUI

struct SystemTileView: View {
    var system: HomeSystem
    var health: HealthSnapshot
    var nextDate: Date?

    var body: some View {
        SurfaceCard {
            HStack(spacing: 14) {
                Image(systemName: system.photoSymbol)
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(system.name)
                        .font(.headline)
                    Text(system.brandModel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let nextDate {
                        Text("Next: \(nextDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                ScoreRingView(score: health.score, band: health.band, size: 64)
            }
        }
    }
}
