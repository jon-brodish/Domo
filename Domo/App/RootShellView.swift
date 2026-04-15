import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case systems
    case tasks
    case schedule
    case insights
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Overview"
        case .systems: return "Systems"
        case .tasks: return "Tasks"
        case .schedule: return "Schedule"
        case .insights: return "Review"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .systems: return "house"
        case .tasks: return "checklist"
        case .schedule: return "calendar"
        case .insights: return "checkmark.seal"
        case .settings: return "gearshape"
        }
    }
}

struct RootShellView: View {
    @EnvironmentObject private var store: HomeStore
    @State private var selectedSection: AppSection = .dashboard

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("Home")
            .listStyle(.sidebar)
        } detail: {
            sectionView(for: selectedSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
        }
#else
        TabView {
            ForEach(AppSection.allCases) { section in
                NavigationStack {
                    sectionView(for: section)
                        .background(AppTheme.background)
                }
                .tabItem {
                    Label(section.title, systemImage: section.symbol)
                }
            }
        }
#endif
    }

    @ViewBuilder
    private func sectionView(for section: AppSection) -> some View {
        switch section {
        case .dashboard:
            DashboardView()
        case .systems:
            SystemsListView()
        case .tasks:
            TasksView()
        case .schedule:
            ScheduleView()
        case .insights:
            InsightsView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    RootShellView()
        .environmentObject(HomeStore(aiService: MockAISetupService()))
}
