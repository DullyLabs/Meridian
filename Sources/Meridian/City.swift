import Foundation

/// A place to show the time for: a named city in a time zone, or this Mac's own time zone.
struct City: Identifiable, Hashable {
    static let local = City(name: "", zone: localID)
    static let defaults: [City] = [.local] + ["London", "New York", "Tokyo", "UTC"].compactMap { name in all.first { $0.name == name } }

    private static let localID = "local"

    let name: String
    let zone: String

    var id: String { zone == Self.localID ? zone : "\(name)|\(zone)" }
    var isLocal: Bool { zone == Self.localID }
    var timeZone: TimeZone { isLocal ? .autoupdatingCurrent : TimeZone(identifier: zone) ?? .current }
    var displayName: String { isLocal ? Self.cityName(TimeZone.autoupdatingCurrent.identifier) : name }

    init(name: String, zone: String) {
        self.name = name
        self.zone = zone
    }

    init?(id: String) {
        if id == Self.localID { self = .local; return }
        let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, TimeZone(identifier: parts[1]) != nil else { return nil }
        self.init(name: parts[0], zone: parts[1])
    }

    static func search(_ query: String) -> [City] {
        query.isEmpty ? all : all.filter { $0.name.localizedStandardContains(query) || $0.zone.localizedStandardContains(query) }
    }

    /// "America/Argentina/Buenos_Aires" -> "Buenos Aires", with legacy zone names given their current spelling.
    static func cityName(_ zone: String) -> String {
        let name = zone.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone
        return renamed[name] ?? name
    }

    private static let renamed = ["Calcutta": "Kolkata", "Katmandu": "Kathmandu", "Rangoon": "Yangon", "Kiev": "Kyiv", "Saigon": "Ho Chi Minh"]

    /// Big cities that share a time zone named after another city, with their own coordinates for the sky colours.
    private static let aliases: [String: (zone: String, latitude: Double, longitude: Double)] = [
        "San Francisco": ("America/Los_Angeles", 37.77, -122.42), "Seattle": ("America/Los_Angeles", 47.61, -122.33),
        "Las Vegas": ("America/Los_Angeles", 36.17, -115.14), "Washington": ("America/New_York", 38.91, -77.04),
        "Boston": ("America/New_York", 42.36, -71.06), "Miami": ("America/New_York", 25.76, -80.19),
        "Atlanta": ("America/New_York", 33.75, -84.39), "Austin": ("America/Chicago", 30.27, -97.74),
        "Dallas": ("America/Chicago", 32.78, -96.80), "Houston": ("America/Chicago", 29.76, -95.37),
        "Montreal": ("America/Toronto", 45.50, -73.57), "Rio de Janeiro": ("America/Sao_Paulo", -22.91, -43.17),
        "Mumbai": ("Asia/Kolkata", 19.08, 72.88), "Delhi": ("Asia/Kolkata", 28.61, 77.21), "Bangalore": ("Asia/Kolkata", 12.97, 77.59),
        "Beijing": ("Asia/Shanghai", 39.90, 116.41), "Shenzhen": ("Asia/Shanghai", 22.54, 114.06), "Abu Dhabi": ("Asia/Dubai", 24.45, 54.38),
        "Hanoi": ("Asia/Ho_Chi_Minh", 21.03, 105.85), "Kyoto": ("Asia/Tokyo", 35.01, 135.77), "Osaka": ("Asia/Tokyo", 34.69, 135.50),
        "Canberra": ("Australia/Sydney", -35.28, 149.13), "Barcelona": ("Europe/Madrid", 41.39, 2.17), "Milan": ("Europe/Rome", 45.46, 9.19),
        "Munich": ("Europe/Berlin", 48.14, 11.58), "Geneva": ("Europe/Zurich", 46.20, 6.14), "Edinburgh": ("Europe/London", 55.95, -3.19),
        "Manchester": ("Europe/London", 53.48, -2.24), "Wellington": ("Pacific/Auckland", -41.29, 174.78), "UTC": ("UTC", 0, 0),
    ]

    /// Where the sun is judged from: the alias's own city, else the zone's main city.
    var coordinate: Coordinate {
        if let alias = Self.aliases[displayName], alias.zone == timeZone.identifier { return Coordinate(latitude: alias.latitude, longitude: alias.longitude) }
        return Sky.coordinate(for: timeZone)
    }

    static let all: [City] = {
        // Current names first, so "Kolkata" gets Asia/Kolkata rather than the old Asia/Calcutta.
        let zones = TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") && !$0.hasPrefix("Etc/") }
            .sorted { Sky.links[$0] == nil && Sky.links[$1] != nil }
        let cities = zones.map { City(name: cityName($0), zone: $0) } + aliases.map { City(name: $0.key, zone: $0.value.zone) }
        var seen = Set<String>()
        return cities.filter { seen.insert($0.name).inserted }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }()
}
