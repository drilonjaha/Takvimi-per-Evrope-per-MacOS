import Foundation

enum Prayer: String, CaseIterable, Identifiable {
    case fajr = "Sabahu"
    case sunrise = "Lindja e Diellit"
    case dhuhr = "Dreka"
    case asr = "Ikindia"
    case maghrib = "Akshami"
    case isha = "Jacia"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fajr: return "sunrise"
        case .sunrise: return "sun.horizon"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.min"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
        }
    }

    // Prayers that require notification (excluding sunrise)
    var isObligatoryPrayer: Bool {
        self != .sunrise
    }
}

struct DailyPrayerTimes: Codable {
    let date: Date
    let city: City
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date
    let hijriDate: String?

    func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .fajr: return fajr
        case .sunrise: return sunrise
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }

    func nextPrayer(after date: Date = Date()) -> (prayer: Prayer, time: Date)? {
        let prayers: [(Prayer, Date)] = [
            (.fajr, fajr),
            (.sunrise, sunrise),
            (.dhuhr, dhuhr),
            (.asr, asr),
            (.maghrib, maghrib),
            (.isha, isha)
        ]

        for (prayer, time) in prayers {
            if time > date {
                return (prayer, time)
            }
        }

        // All prayers passed, next is tomorrow's Fajr
        return nil
    }

    func previousPrayer(before date: Date = Date()) -> (prayer: Prayer, time: Date)? {
        let prayers: [(Prayer, Date)] = [
            (.isha, isha),
            (.maghrib, maghrib),
            (.asr, asr),
            (.dhuhr, dhuhr),
            (.sunrise, sunrise),
            (.fajr, fajr)
        ]

        for (prayer, time) in prayers {
            if time <= date {
                return (prayer, time)
            }
        }

        return nil
    }
}
