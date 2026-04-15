import Foundation

enum VaultDocumentType: String, Codable, CaseIterable, Identifiable {
    case manual = "Manual"
    case receipt = "Receipt"
    case serviceInvoice = "Service Invoice"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .manual: return "book.closed"
        case .receipt: return "receipt"
        case .serviceInvoice: return "doc.text.below.ecg"
        }
    }
}

struct VaultDocument: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var type: VaultDocumentType
    var notes: String
    var systemID: UUID?
    var taskID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        type: VaultDocumentType,
        notes: String = "",
        systemID: UUID? = nil,
        taskID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.notes = notes
        self.systemID = systemID
        self.taskID = taskID
        self.createdAt = createdAt
    }
}
