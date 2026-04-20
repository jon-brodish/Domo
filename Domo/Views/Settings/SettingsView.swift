import SwiftUI

struct SettingsView: View {
    @State private var notificationsEnabled = true
    @State private var weeklyDigest = true

    var body: some View {
        Form {
            Section("Reminders") {
                Toggle("Maintenance notifications", isOn: $notificationsEnabled)
                Toggle("Weekly digest", isOn: $weeklyDigest)
            }

            Section("AI Setup") {
                Text("Connect an API key securely through Keychain or your backend before enabling live AI analysis.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Settings")
    }
}
