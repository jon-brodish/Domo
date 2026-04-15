import SwiftUI

struct SystemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: HomeStore
    @State private var showingAddTask = false
    @State private var showingEditSystem = false
    @State private var showingAIRecommendations = false
    @State private var isLoadingAIRecommendations = false
    @State private var aiSuggestion: AISetupSuggestion?
    @State private var enabledAISuggestionIDs: Set<UUID> = []
    @State private var aiErrorMessage: String?
    @State private var showingDeleteConfirmation = false
    @State private var showingAddDocument = false
    @State private var pendingDeleteTask: MaintenanceTask?
    @State private var selectedTask: MaintenanceTask?
    var system: HomeSystem
    private var displaySystem: HomeSystem {
        store.systems.first(where: { $0.id == system.id }) ?? system
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                facts
                tasksSection
                notesSection
                docsAndAI
                deleteSection
            }
            .padding(20)
        }
        .navigationTitle(displaySystem.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEditSystem = true
                } label: {
                    Label("Edit System", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete System", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            TaskEditorSheetView(
                isPresented: $showingAddTask,
                preselectedSystemID: displaySystem.id,
                lockSystemSelection: true
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showingEditSystem) {
            SystemEditorSheetView(isPresented: $showingEditSystem, system: displaySystem)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingAddDocument) {
            DocumentEditorSheetView(
                isPresented: $showingAddDocument,
                prefilledSystemID: displaySystem.id,
                prefilledTaskID: nil
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showingAIRecommendations) {
            if let aiSuggestion {
                AIRecommendationsSheetView(
                    isPresented: $showingAIRecommendations,
                    suggestion: aiSuggestion,
                    selectedTaskIDs: $enabledAISuggestionIDs
                ) {
                    applyAISuggestions()
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheetView(task: task)
                .environmentObject(store)
        }
        .alert(
            "AI Recommendations Unavailable",
            isPresented: Binding(
                get: { aiErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { aiErrorMessage = nil }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    aiErrorMessage = nil
                }
            },
            message: {
                Text(aiErrorMessage ?? "Please try again.")
            }
        )
        .alert(
            "Delete System?",
            isPresented: $showingDeleteConfirmation,
            actions: {
                Button("Delete", role: .destructive) {
                    store.deleteSystem(displaySystem)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("Delete \(displaySystem.name)? This also removes its linked tasks.")
            }
        )
        .alert(
            "Delete Task?",
            isPresented: Binding(
                get: { pendingDeleteTask != nil },
                set: { isPresented in
                    if !isPresented { pendingDeleteTask = nil }
                }
            ),
            actions: {
                Button("Delete", role: .destructive) {
                    guard let task = pendingDeleteTask else { return }
                    store.deleteTask(task)
                    pendingDeleteTask = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteTask = nil
                }
            },
            message: {
                if let task = pendingDeleteTask {
                    Text("Delete \(task.title)?")
                }
            }
        )
    }

    private var header: some View {
        SurfaceCard {
            HStack(spacing: 16) {
                Image(systemName: displaySystem.photoSymbol)
                    .font(.system(size: 34, weight: .regular))
                    .frame(width: 74, height: 74)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(displaySystem.brandModel)
                        .font(.title3.weight(.semibold))
                    Text(displaySystem.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }

                Spacer()

                let health = store.healthSnapshot(for: displaySystem)
                VStack(spacing: 6) {
                    Text("Health")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScoreRingView(score: health.score, band: health.band, size: 82)
                }
            }
        }
    }

    private var facts: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                KeyValueRow(label: "Install Date", value: displaySystem.installDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                KeyValueRow(label: "Age", value: ageText)
                KeyValueRow(label: "Last Service", value: displaySystem.lastServiceDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not yet logged")
                KeyValueRow(label: "Warranty", value: warrantyText)
                KeyValueRow(label: "Next Maintenance", value: store.nextMaintenanceDate(for: displaySystem)?.formatted(date: .abbreviated, time: .omitted) ?? "No upcoming tasks")
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(title: "Recurring Maintenance")
                Spacer()
                Button {
                    showingAddTask = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.14))
                            )
                        Text("Add Task")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
            SurfaceCard {
                let systemTasks = store.tasks(for: displaySystem)
                if systemTasks.isEmpty {
                    Text("No tasks yet. Add recurring care to improve score confidence.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(systemTasks) { task in
                        TaskRowView(task: task, systemName: nil, isPendingCompletion: store.isPendingCompletion(task)) {
                            store.toggleTaskCompletion(task)
                        } onSelect: {
                            selectedTask = task
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteTask = task
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Notes")
            SurfaceCard {
                Text(displaySystem.notes.isEmpty ? "No notes yet." : displaySystem.notes)
                    .font(.body)
                    .foregroundStyle(displaySystem.notes.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var docsAndAI: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Document Vault & AI")
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Attached documents")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button("Add") {
                            showingAddDocument = true
                        }
                    }

                    let attachedDocs = store.documents(for: displaySystem.id)
                    if attachedDocs.isEmpty {
                        Label("No documents yet", systemImage: "doc")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachedDocs) { document in
                            HStack {
                                Label(document.title, systemImage: document.type.symbol)
                                    .font(.subheadline)
                                Spacer()
                                Button(role: .destructive) {
                                    store.deleteDocument(document.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Use AI Setup to refine maintenance intervals based on model details and photo evidence.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await fetchAIRecommendations() }
                    } label: {
                        if isLoadingAIRecommendations {
                            ProgressView()
                        } else {
                            Text("Open AI Recommendations")
                        }
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoadingAIRecommendations)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var deleteSection: some View {
        SurfaceCard {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete System")
                    Spacer()
                }
                .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }

    private var ageText: String {
        guard let installDate = displaySystem.installDate,
              let years = Calendar.current.dateComponents([.year], from: installDate, to: .now).year else {
            return "Unknown"
        }
        return "\(years) years"
    }

    private var warrantyText: String {
        guard let expiration = displaySystem.warrantyExpirationDate else { return "Not set" }
        if expiration < .now {
            return "Expired \(expiration.formatted(date: .abbreviated, time: .omitted))"
        }
        return expiration.formatted(date: .abbreviated, time: .omitted)
    }

    private func fetchAIRecommendations() async {
        isLoadingAIRecommendations = true
        defer { isLoadingAIRecommendations = false }

        let hint = """
        Existing system details:
        Name: \(displaySystem.name)
        Category: \(displaySystem.category.rawValue)
        Brand model: \(displaySystem.brandModel)
        Notes: \(displaySystem.notes)
        """

        do {
            let suggestion = try await store.runAISetup(
                input: AISetupInput(imageData: nil, userHint: hint)
            )
            aiSuggestion = suggestion
            enabledAISuggestionIDs = Set(suggestion.tasks.map(\.id))
            showingAIRecommendations = true
        } catch {
            aiErrorMessage = "Could not load recommendations. Please try again."
        }
    }

    private func applyAISuggestions() {
        guard let suggestion = aiSuggestion else { return }
        let selected = suggestion.tasks.filter { enabledAISuggestionIDs.contains($0.id) }

        for task in selected {
            store.addTask(
                title: task.title,
                notes: task.notes,
                dueDate: Calendar.current.date(byAdding: .day, value: task.recurrence.intervalDays, to: .now) ?? .now,
                recurrence: task.recurrence,
                systemID: displaySystem.id,
                priority: task.priority,
                origin: .suggested
            )
        }

        showingAIRecommendations = false
    }
}

private struct SystemEditorSheetView: View {
    @EnvironmentObject private var store: HomeStore
    @Binding var isPresented: Bool
    let system: HomeSystem

    @State private var name: String
    @State private var brandModel: String
    @State private var category: HomeSystemCategory
    @State private var installDate: Date
    @State private var hasInstallDate: Bool
    @State private var lastServiceDate: Date
    @State private var hasLastServiceDate: Bool
    @State private var notes: String
    @State private var hasWarrantyExpirationDate: Bool
    @State private var warrantyExpirationDate: Date

    init(isPresented: Binding<Bool>, system: HomeSystem) {
        _isPresented = isPresented
        self.system = system
        _name = State(initialValue: system.name)
        _brandModel = State(initialValue: system.brandModel)
        _category = State(initialValue: system.category)
        _installDate = State(initialValue: system.installDate ?? .now)
        _hasInstallDate = State(initialValue: system.installDate != nil)
        _lastServiceDate = State(initialValue: system.lastServiceDate ?? .now)
        _hasLastServiceDate = State(initialValue: system.lastServiceDate != nil)
        _notes = State(initialValue: system.notes)
        _hasWarrantyExpirationDate = State(initialValue: system.warrantyExpirationDate != nil)
        _warrantyExpirationDate = State(initialValue: system.warrantyExpirationDate ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("System") {
                    TextField("Name", text: $name)
                    TextField("Brand / Model", text: $brandModel)
                    Picker("Category", selection: $category) {
                        ForEach(HomeSystemCategory.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }

                Section("Dates") {
                    Toggle("Known install date", isOn: $hasInstallDate)
                    if hasInstallDate {
                        DatePicker("Install Date", selection: $installDate, displayedComponents: .date)
                    }

                    Toggle("Last service logged", isOn: $hasLastServiceDate)
                    if hasLastServiceDate {
                        DatePicker("Last Service", selection: $lastServiceDate, displayedComponents: .date)
                    }

                    Toggle("Warranty expiration known", isOn: $hasWarrantyExpirationDate)
                    if hasWarrantyExpirationDate {
                        DatePicker("Warranty Expires", selection: $warrantyExpirationDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit System")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateSystem(
                            system.id,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            brandModel: brandModel.trimmingCharacters(in: .whitespacesAndNewlines),
                            installDate: hasInstallDate ? installDate : nil,
                            lastServiceDate: hasLastServiceDate ? lastServiceDate : nil,
                            warrantyExpirationDate: hasWarrantyExpirationDate ? warrantyExpirationDate : nil,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        isPresented = false
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AIRecommendationsSheetView: View {
    @Binding var isPresented: Bool
    let suggestion: AISetupSuggestion
    @Binding var selectedTaskIDs: Set<UUID>
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("AI Suggestion")
                        .font(.headline)
                    Text("\(Int(suggestion.confidence * 100))% confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    KeyValueRow(label: "Name", value: suggestion.suggestedName)
                    KeyValueRow(label: "Category", value: suggestion.category.rawValue)
                    KeyValueRow(label: "Model", value: suggestion.brandModel)

                    Divider()

                    Text("Select tasks to add")
                        .font(.subheadline.weight(.medium))

                    ForEach(suggestion.tasks) { task in
                        Toggle(isOn: Binding(
                            get: { selectedTaskIDs.contains(task.id) },
                            set: { isOn in
                                if isOn { selectedTaskIDs.insert(task.id) }
                                else { selectedTaskIDs.remove(task.id) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                Text(task.recurrence.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("AI Recommendations")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected") {
                        onApply()
                    }
                    .disabled(selectedTaskIDs.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SystemDetailView(system: SampleDataFactory.seed().systems[0])
            .environmentObject(HomeStore(aiService: MockAISetupService()))
    }
}
