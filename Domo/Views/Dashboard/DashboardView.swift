import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var showingAddSystem = false
    @State private var showingAddTask = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero

                HStack(spacing: 12) {
                    InsightBadge(title: "Due Soon", value: "\(store.dueSoonTasks.count)", symbol: "clock")
                    InsightBadge(title: "Overdue", value: "\(store.overdueTasks.count)", symbol: "exclamationmark.triangle")
                    InsightBadge(title: "Completed", value: "\(store.recentlyCompleted.count)", symbol: "checkmark")
                }

                SectionTitle(title: "Due Soon", subtitle: "What needs attention this week")
                SurfaceCard {
                    if store.dueSoonTasks.isEmpty {
                        Text("Everything is current for this week.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.dueSoonTasks.prefix(4)) { task in
                            TaskRowView(task: task, systemName: systemName(for: task), isPendingCompletion: store.isPendingCompletion(task)) {
                                store.toggleTaskCompletion(task)
                            }
                        }
                    }
                }

                SectionTitle(title: "Overdue", subtitle: "High-impact items to resolve first")
                SurfaceCard {
                    if store.overdueTasks.isEmpty {
                        Text("No overdue tasks right now.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.overdueTasks.prefix(4)) { task in
                            TaskRowView(task: task, systemName: systemName(for: task), isPendingCompletion: store.isPendingCompletion(task)) {
                                store.toggleTaskCompletion(task)
                            }
                        }
                    }
                }

                SectionTitle(title: "Systems", subtitle: "Health across major home categories")
                LazyVStack(spacing: 12) {
                    ForEach(store.systems.prefix(6)) { system in
                        NavigationLink {
                            SystemDetailView(system: system)
                        } label: {
                            SystemTileView(system: system, health: store.healthSnapshot(for: system), nextDate: store.nextMaintenanceDate(for: system))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddSystem = true
                    } label: {
                        Label("System", systemImage: "house")
                    }

                    Button {
                        showingAddTask = true
                    } label: {
                        Label("Task", systemImage: "checklist")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSystem) {
            AddSystemFlowView(isPresented: $showingAddSystem)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingAddTask) {
            TaskEditorSheetView(isPresented: $showingAddTask)
                .environmentObject(store)
        }
    }

    private var hero: some View {
        SurfaceCard {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Home Health")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(store.overallHealthScore >= 90 ? "Maintenance is in great shape" : "A few systems need attention")
                        .font(.title3.weight(.semibold))
                    Text("This month: keep recurring routines steady and tackle overdue items first.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ScoreRingView(score: store.overallHealthScore, band: band(for: store.overallHealthScore), size: 102)
            }
        }
    }

    private func band(for score: Int) -> HealthBand {
        switch score {
        case 90...100: return .excellent
        case 70...89: return .good
        case 40...69: return .needsAttention
        default: return .poor
        }
    }

    private func systemName(for task: MaintenanceTask) -> String? {
        guard let id = task.systemID else { return nil }
        return store.systems.first(where: { $0.id == id })?.name
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(HomeStore(aiService: MockAISetupService()))
    }
}
