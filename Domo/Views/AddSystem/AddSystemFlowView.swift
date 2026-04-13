import PhotosUI
import SwiftUI

enum AddFlowMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case ai = "AI Assist"

    var id: String { rawValue }
}

struct AddSystemFlowView: View {
    @EnvironmentObject private var store: HomeStore
    @Binding var isPresented: Bool

    @State private var mode: AddFlowMode = .manual

    @State private var name = ""
    @State private var brandModel = ""
    @State private var category: HomeSystemCategory = .custom
    @State private var installDate = Date()
    @State private var usesInstallDate = true
    @State private var notes = ""

    @State private var aiHint = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isAnalyzing = false
    @State private var suggestion: AISetupSuggestion?
    @State private var enabledSuggestions = Set<UUID>()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Mode", selection: $mode) {
                        ForEach(AddFlowMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .manual {
                        manualForm
                    } else {
                        aiForm
                    }
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .navigationTitle("Add Home Item")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 560, minHeight: 620)
#else
        .presentationDetents([.large])
#endif
    }

    private var manualForm: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Brand / Model", text: $brandModel)
                    .textFieldStyle(.roundedBorder)
                Picker("Category", selection: $category) {
                    ForEach(HomeSystemCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }

                Toggle("Known install date", isOn: $usesInstallDate)
                if usesInstallDate {
                    DatePicker("Install Date", selection: $installDate, displayedComponents: .date)
                }

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var aiForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Take or choose a photo, then review AI suggestions before saving.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose Appliance Photo", systemImage: "photo")
                    }

                    TextField("Optional hint (e.g. HVAC in attic)", text: $aiHint)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task { await runAI() }
                    } label: {
                        if isAnalyzing {
                            ProgressView()
                        } else {
                            Label("Analyze with AI", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzing)
                }
            }

            if let suggestion {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI Suggestion")
                            .font(.headline)
                        Text("\(Int(suggestion.confidence * 100))% confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        KeyValueRow(label: "Name", value: suggestion.suggestedName)
                        KeyValueRow(label: "Category", value: suggestion.category.rawValue)
                        KeyValueRow(label: "Model", value: suggestion.brandModel)

                        Divider()
                        Text("Review suggested tasks before saving")
                            .font(.subheadline.weight(.medium))

                        ForEach(suggestion.tasks) { task in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { enabledSuggestions.contains(task.id) },
                                    set: { isOn in
                                        if isOn { enabledSuggestions.insert(task.id) }
                                        else { enabledSuggestions.remove(task.id) }
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
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        switch mode {
        case .manual:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .ai:
            return suggestion != nil
        }
    }

    private func runAI() async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        if let selectedItem,
           let data = try? await selectedItem.loadTransferable(type: Data.self) {
            photoData = data
        }

        if let result = try? await store.runAISetup(input: AISetupInput(imageData: photoData, userHint: aiHint)) {
            suggestion = result
            enabledSuggestions = Set(result.tasks.map(\.id))
        }
    }

    private func save() {
        switch mode {
        case .manual:
            let newSystem = HomeSystem(
                name: name,
                category: category,
                brandModel: brandModel,
                installDate: usesInstallDate ? installDate : nil,
                lastServiceDate: nil,
                notes: notes,
                photoSymbol: category.symbol,
                createdFromAI: false
            )
            store.addSystem(newSystem, tasks: [])

        case .ai:
            guard let suggestion else { return }

            let system = HomeSystem(
                name: suggestion.suggestedName,
                category: suggestion.category,
                brandModel: suggestion.brandModel,
                installDate: nil,
                lastServiceDate: nil,
                notes: suggestion.notes,
                photoSymbol: suggestion.photoSymbol,
                createdFromAI: true
            )

            let selected = suggestion.tasks.filter { enabledSuggestions.contains($0.id) }
            let tasks = selected.map { item in
                MaintenanceTask(
                    title: item.title,
                    notes: item.notes,
                    dueDate: Calendar.current.date(byAdding: .day, value: item.recurrence.intervalDays, to: .now) ?? .now,
                    recurrence: item.recurrence,
                    systemID: system.id,
                    priority: item.priority,
                    origin: .suggested
                )
            }

            store.addSystem(system, tasks: tasks)
        }

        isPresented = false
    }
}

#Preview {
    AddSystemFlowView(isPresented: .constant(true))
        .environmentObject(HomeStore(aiService: MockAISetupService()))
}
