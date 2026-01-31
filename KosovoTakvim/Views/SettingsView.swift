import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("selectedCityId") private var selectedCityId: String = City.default.id
    @AppStorage("showPrayerName") private var showPrayerName: Bool = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    @Environment(\.dismiss) private var dismiss

    var onCityChange: ((City) -> Void)?
    var onNotificationToggle: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Cilësimet")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // City Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("Qyteti")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("Qyteti", selection: $selectedCityId) {
                    ForEach(City.allCities) { city in
                        Text(city.name).tag(city.id)
                    }
                }
                .labelsHidden()
                .onChange(of: selectedCityId) { _, newValue in
                    if let city = City.find(by: newValue) {
                        onCityChange?(city)
                    }
                }
            }

            Divider()

            // Display Options
            VStack(alignment: .leading, spacing: 10) {
                Text("Shfaqja")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Toggle("Shfaq emrin e namazit", isOn: $showPrayerName)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
            }

            Divider()

            // Notifications
            VStack(alignment: .leading, spacing: 10) {
                Text("Njoftimet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Toggle("Aktivizo njoftimet", isOn: $notificationsEnabled)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                    .onChange(of: notificationsEnabled) { _, newValue in
                        onNotificationToggle?(newValue)
                    }
            }

            Divider()

            // Launch at Login
            VStack(alignment: .leading, spacing: 10) {
                Text("Sistemi")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Toggle("Hap me ndezjen e kompjuterit", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }

            Spacer()

            // Footer
            HStack {
                Spacer()
                Text("Takvimi v1.0")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 280, height: 380)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}

#Preview {
    SettingsView()
}
