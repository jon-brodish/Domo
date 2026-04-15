import SwiftUI

struct DocumentEditorSheetView: View {
    @EnvironmentObject private var store: HomeStore
    @Binding var isPresented: Bool

    var prefilledSystemID: UUID?
    var prefilledTaskID: UUID?

    @State private var title = ""
    @State private var type: VaultDocumentType = .manual
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $type) {
                        ForEach(VaultDocumentType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Document")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addDocument(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            type: type,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            systemID: prefilledSystemID,
                            taskID: prefilledTaskID
                        )
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
