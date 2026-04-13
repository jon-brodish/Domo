import Foundation

struct MockAISetupService: AISetupService {
    func analyze(input: AISetupInput) async throws -> AISetupSuggestion {
        try await Task.sleep(for: .milliseconds(800))

        let hint = input.userHint.lowercased()

        if hint.contains("hvac") || hint.contains("furnace") {
            return AISetupSuggestion(
                suggestedName: "Main HVAC",
                category: .hvac,
                brandModel: "Carrier 59TP6",
                confidence: 0.82,
                photoSymbol: "wind",
                notes: "Detected forced-air HVAC system. Review intervals for local climate and filter type.",
                tasks: [
                    AIRecommendedTask(title: "Change air filter", notes: "Use MERV rating recommended by manufacturer.", recurrence: .every(days: 90), priority: .high),
                    AIRecommendedTask(title: "Schedule seasonal tune-up", notes: "Book spring/fall tune-up with technician.", recurrence: .every(days: 180), priority: .medium),
                    AIRecommendedTask(title: "Clean supply/return vents", notes: "Vacuum vents and inspect for dust buildup.", recurrence: .every(days: 365), priority: .low),
                    AIRecommendedTask(title: "Flush condensate drain line", notes: "Use approved cleaner to prevent clogs.", recurrence: .every(days: 120), priority: .medium)
                ]
            )
        }

        if hint.contains("water") || hint.contains("heater") {
            return AISetupSuggestion(
                suggestedName: "Water Heater",
                category: .water,
                brandModel: "Rheem Performance 40 Gal",
                confidence: 0.76,
                photoSymbol: "drop",
                notes: "Detected tank water heater. Confirm capacity and install year.",
                tasks: [
                    AIRecommendedTask(title: "Flush water heater", notes: "Drain sediment to improve longevity.", recurrence: .every(days: 180), priority: .high),
                    AIRecommendedTask(title: "Inspect T&P relief valve", notes: "Verify valve operation and no leakage.", recurrence: .every(days: 365), priority: .medium)
                ]
            )
        }

        return AISetupSuggestion(
            suggestedName: "Kitchen Refrigerator",
            category: .kitchen,
            brandModel: "Whirlpool WRS315",
            confidence: 0.7,
            photoSymbol: "refrigerator",
            notes: "Likely refrigerator appliance. Confirm exact model before saving.",
            tasks: [
                AIRecommendedTask(title: "Replace water filter", notes: "Install manufacturer-compatible filter cartridge.", recurrence: .every(days: 180), priority: .high),
                AIRecommendedTask(title: "Clean condenser coils", notes: "Vacuum rear or bottom coils for efficiency.", recurrence: .every(days: 180), priority: .medium),
                AIRecommendedTask(title: "Inspect door seals", notes: "Check gasket for cracks and clean as needed.", recurrence: .every(days: 180), priority: .low)
            ]
        )
    }
}
