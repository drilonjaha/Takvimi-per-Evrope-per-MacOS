import Foundation

struct City: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    static let allCities: [City] = [
        City(id: "prishtina", name: "Prishtina", latitude: 42.6629, longitude: 21.1655),
        City(id: "prizren", name: "Prizren", latitude: 42.2139, longitude: 20.7397),
        City(id: "peja", name: "Peja", latitude: 42.6592, longitude: 20.2883),
        City(id: "gjakova", name: "Gjakova", latitude: 42.3803, longitude: 20.4308),
        City(id: "mitrovica", name: "Mitrovica", latitude: 42.8914, longitude: 20.8660),
        City(id: "ferizaj", name: "Ferizaj", latitude: 42.3702, longitude: 21.1553),
        City(id: "gjilan", name: "Gjilan", latitude: 42.4635, longitude: 21.4694)
    ]

    static let `default` = allCities[0] // Prishtina

    static func find(by id: String) -> City? {
        allCities.first { $0.id == id }
    }
}
