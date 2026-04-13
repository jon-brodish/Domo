import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: HomeStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Health Insights", subtitle: "Simple signals that guide next actions")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        KeyValueRow(label: "Overall score", value: "\(store.overallHealthScore)")
                        KeyValueRow(label: "Overdue tasks", value: "\(store.overdueTasks.count)")
                        KeyValueRow(label: "Due this week", value: "\(store.dueSoonTasks.count)")
                    }
                }

                SurfaceCard {
                    Text("Improve confidence by adding model details and install date for each major system.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .navigationTitle("Insights")
    }
}
