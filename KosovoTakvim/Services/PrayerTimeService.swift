import Foundation

enum PrayerTimeError: Error, LocalizedError {
    case networkError(Error)
    case invalidResponse
    case parsingError
    case noCache
    case noDataForDate

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError:
            return "Failed to parse prayer times"
        case .noCache:
            return "No cached data available"
        case .noDataForDate:
            return "No prayer times available for this date"
        }
    }
}

actor PrayerTimeService {
    static let shared = PrayerTimeService()

    private var cache: [String: DailyPrayerTimes] = [:]
    private let cacheKey = "cachedPrayerTimes_v3" // v3: IZRS Swiss calculation method
    private let oldCacheKeys = ["cachedPrayerTimes", "cachedPrayerTimes_v2"] // Old cache keys to clear

    init() {
        // Clear old cache from previous versions
        for oldKey in oldCacheKeys {
            UserDefaults.standard.removeObject(forKey: oldKey)
        }
        loadCacheFromDisk()
    }

    func fetchPrayerTimes(for city: City, date: Date = Date()) async throws -> DailyPrayerTimes {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)

        // For 2026 Kosovo cities: use official BIM data
        if year == 2026 && city.country == .kosovo {
            if let times = PrayerTimesData2026.getPrayerTimes(for: date, city: city) {
                let cacheId = cacheKey(for: city, date: date)
                cache[cacheId] = times
                saveCacheToDisk()
                return times
            }
        }

        let cacheId = cacheKey(for: city, date: date)

        // For non-Kosovo cities (and non-2026 Kosovo), check cache
        if let cached = cache[cacheId] {
            // Verify cache entry is for the correct city (prevent cross-contamination)
            if cached.city.id == city.id {
                return cached
            }
        }

        // Fetch from API with city-specific coordinates
        do {
            let times = try await fetchFromAPI(city: city, date: date)
            cache[cacheId] = times
            saveCacheToDisk()
            return times
        } catch {
            // Only use fallback cache for the SAME city, not any random cache entry
            if let fallback = cache[cacheId], fallback.city.id == city.id {
                return fallback
            }
            throw error
        }
    }

    private func fetchFromAPI(city: City, date: Date) async throws -> DailyPrayerTimes {
        let baseURL = "https://api.aladhan.com/v1/timings"

        // Get calculation settings based on country
        let (methodSettings, tune) = getCalculationSettings(for: city, date: date)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let dateString = dateFormatter.string(from: date)

        // Get timezone identifier for the city's country
        let timezone = getTimezone(for: city)

        var components = URLComponents(string: "\(baseURL)/\(dateString)")!
        var queryItems = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "method", value: "99"),
            URLQueryItem(name: "methodSettings", value: methodSettings),
            URLQueryItem(name: "timezonestring", value: timezone)
        ]

        // Add tune parameter if needed (for IZRS Swiss adjustments)
        if let tune = tune {
            queryItems.append(URLQueryItem(name: "tune", value: tune))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw PrayerTimeError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PrayerTimeError.invalidResponse
        }

        let aladhanResponse = try JSONDecoder().decode(AladhanResponse.self, from: data)
        return try parsePrayerTimes(from: aladhanResponse, city: city, date: date)
    }

    private func parsePrayerTimes(from response: AladhanResponse, city: City, date: Date) throws -> DailyPrayerTimes {
        let timings = response.data.timings
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        func parseTime(_ timeString: String) -> Date? {
            let parts = timeString.components(separatedBy: " ").first ?? timeString
            let timeParts = parts.components(separatedBy: ":")
            guard timeParts.count == 2,
                  let hour = Int(timeParts[0]),
                  let minute = Int(timeParts[1]) else {
                return nil
            }

            var components = dateComponents
            components.hour = hour
            components.minute = minute
            components.second = 0
            return calendar.date(from: components)
        }

        // Use Imsak from API (Fajr/Sabahu will be calculated as Imsak + 35 min)
        guard let imsak = parseTime(timings.Imsak),
              let sunrise = parseTime(timings.Sunrise),
              let dhuhr = parseTime(timings.Dhuhr),
              let asr = parseTime(timings.Asr),
              let maghrib = parseTime(timings.Maghrib),
              let isha = parseTime(timings.Isha) else {
            throw PrayerTimeError.parsingError
        }

        let hijri = response.data.date.hijri
        let hijriDate = "\(hijri.day) \(hijri.month.en) \(hijri.year)"

        // Fajr/Sabahu is automatically calculated as Imsak + 35 min in the initializer
        return DailyPrayerTimes(
            date: date,
            city: city,
            imsak: imsak,
            sunrise: sunrise,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            hijriDate: hijriDate
        )
    }

    private func cacheKey(for city: City, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "\(city.id)_\(dateFormatter.string(from: date))"
    }

    // Returns (methodSettings, tune) - tune is optional for Fajr/Isha adjustments
    private func getCalculationSettings(for city: City, date: Date) -> (String, String?) {
        switch city.country {
        case .switzerland:
            // IZRS Switzerland recommended settings
            // Uses UOIF angles (12° Fajr, 12° Isha) with seasonal Fajr adjustments
            // Source: https://www.izrs.ch/empirisch-fundierte-winkelbestimmung-definitive-gebetszeiten-fuer-die-schweiz.html
            let calendar = Calendar.current
            let month = calendar.component(.month, from: date)
            let day = calendar.component(.day, from: date)

            // Seasonal adjustment for Fajr:
            // Sept 23 - March 20: -5 minutes
            // March 21 - Sept 22: -10 minutes
            let isWinterPeriod = (month > 9 || month < 3 || (month == 9 && day >= 23) || (month == 3 && day <= 20))
            let fajrAdjust = isWinterPeriod ? -5 : -10

            // tune format: Imsak,Fajr,Sunrise,Dhuhr,Asr,Maghrib,Isha,Midnight
            let tune = "\(fajrAdjust),\(fajrAdjust),0,0,0,0,0,0"
            return ("12,null,12", tune) // UOIF angles

        case .kosovo:
            // BIM Kosovo angles (used for API fallback, main data is embedded)
            return ("18,null,17", nil)

        default:
            // Default: BIM Kosovo angles for other European countries
            return ("18,null,17", nil)
        }
    }

    private func getTimezone(for city: City) -> String {
        switch city.country {
        case .kosovo: return "Europe/Belgrade" // Kosovo uses CET (same as Serbia)
        case .switzerland: return "Europe/Zurich"
        case .germany: return "Europe/Berlin"
        case .austria: return "Europe/Vienna"
        case .france: return "Europe/Paris"
        case .netherlands: return "Europe/Amsterdam"
        case .belgium: return "Europe/Brussels"
        case .sweden: return "Europe/Stockholm"
        case .norway: return "Europe/Oslo"
        case .denmark: return "Europe/Copenhagen"
        case .unitedKingdom: return "Europe/London"
        case .italy: return "Europe/Rome"
        case .finland: return "Europe/Helsinki"
        }
    }

    private func loadCacheFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: DailyPrayerTimes].self, from: data) else {
            return
        }
        cache = decoded
    }

    private func saveCacheToDisk() {
        guard let encoded = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }

    func clearCache() {
        cache.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}
