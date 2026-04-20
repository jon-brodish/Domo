import SwiftUI

struct SectionTitle: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.primary.opacity(0.92))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
