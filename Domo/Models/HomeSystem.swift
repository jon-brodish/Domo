import Foundation
import SwiftUI

enum HomeSystemCategory: String, CaseIterable, Identifiable, Codable {
    case hvac = "HVAC"
    case water = "Water"
    case kitchen = "Kitchen"
    case laundry = "Laundry"
    case safety = "Safety"
    case exterior = "Exterior"
    case airQuality = "Air Quality"
    case custom = "Custom"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .hvac: return "wind"
        case .water: return "drop"
        case .kitchen: return "fork.knife"
        case .laundry: return "washer"
        case .safety: return "checkmark.shield"
        case .exterior: return "leaf"
        case .airQuality: return "aqi.medium"
        case .custom: return "square.grid.2x2"
        }
    }
}

struct HomeSystem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: HomeSystemCategory
    var brandModel: String
    var installDate: Date?
    var lastServiceDate: Date?
    var notes: String
    var photoSymbol: String
    var documentPlaceholder: String
    var createdFromAI: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: HomeSystemCategory,
        brandModel: String,
        installDate: Date? = nil,
        lastServiceDate: Date? = nil,
        notes: String = "",
        photoSymbol: String,
        documentPlaceholder: String = "Manual.pdf",
        createdFromAI: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.brandModel = brandModel
        self.installDate = installDate
        self.lastServiceDate = lastServiceDate
        self.notes = notes
        self.photoSymbol = photoSymbol
        self.documentPlaceholder = documentPlaceholder
        self.createdFromAI = createdFromAI
    }
}
