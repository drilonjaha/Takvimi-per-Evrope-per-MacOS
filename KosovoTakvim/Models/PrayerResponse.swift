import Foundation

// Aladhan API Response Models
struct AladhanResponse: Codable {
    let code: Int
    let status: String
    let data: AladhanData
}

struct AladhanData: Codable {
    let timings: AladhanTimings
    let date: AladhanDate
}

struct AladhanTimings: Codable {
    let Fajr: String
    let Sunrise: String
    let Dhuhr: String
    let Asr: String
    let Maghrib: String
    let Isha: String
}

struct AladhanDate: Codable {
    let readable: String
    let hijri: HijriDate
    let gregorian: GregorianDate
}

struct HijriDate: Codable {
    let date: String
    let day: String
    let month: HijriMonth
    let year: String
}

struct HijriMonth: Codable {
    let number: Int
    let en: String
    let ar: String
}

struct GregorianDate: Codable {
    let date: String
    let day: String
    let month: GregorianMonth
    let year: String
}

struct GregorianMonth: Codable {
    let number: Int
    let en: String
}
