import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func schedulePrayerNotification(for prayer: Prayer, at time: Date, city: String) async {
        guard prayer.isObligatoryPrayer else { return }

        let content = UNMutableNotificationContent()
        content.title = "Koha e Namazit"
        content.body = "\(prayer.rawValue) - \(city)"
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let identifier = "prayer_\(prayer.rawValue)_\(time.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    func scheduleAllPrayerNotifications(times: DailyPrayerTimes) async {
        // Cancel existing notifications first
        await cancelAllNotifications()

        for prayer in Prayer.allCases where prayer.isObligatoryPrayer {
            let prayerTime = times.time(for: prayer)
            if prayerTime > Date() {
                await schedulePrayerNotification(for: prayer, at: prayerTime, city: times.city.name)
            }
        }
    }

    func cancelAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
