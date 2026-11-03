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

    /// Big cities that share a time zone named after another city.
    private static let aliases = [
        "San Francisco": "America/Los_Angeles", "Seattle": "America/Los_Angeles", "Las Vegas": "America/Los_Angeles",
        "Washington": "America/New_York", "Boston": "America/New_York", "Miami": "America/New_York", "Atlanta": "America/New_York",
        "Austin": "America/Chicago", "Dallas": "America/Chicago", "Houston": "America/Chicago",
        "Montreal": "America/Toronto", "Rio de Janeiro": "America/Sao_Paulo",
        "Mumbai": "Asia/Kolkata", "Delhi": "Asia/Kolkata", "Bangalore": "Asia/Kolkata",
        "Beijing": "Asia/Shanghai", "Shenzhen": "Asia/Shanghai", "Abu Dhabi": "Asia/Dubai", "Hanoi": "Asia/Ho_Chi_Minh",
        "Kyoto": "Asia/Tokyo", "Osaka": "Asia/Tokyo", "Canberra": "Australia/Sydney",
        "Barcelona": "Europe/Madrid", "Milan": "Europe/Rome", "Munich": "Europe/Berlin", "Geneva": "Europe/Zurich",
        "Edinburgh": "Europe/London", "Manchester": "Europe/London", "Wellington": "Pacific/Auckland", "UTC": "UTC",
    ]

    static let all: [City] = {
        let zones = TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") && !$0.hasPrefix("Etc/") }
        let cities = zones.map { City(name: cityName($0), zone: $0) } + aliases.map { City(name: $0.key, zone: $0.value) }
        var seen = Set<String>()
        return cities.filter { seen.insert($0.name).inserted }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }()
}
