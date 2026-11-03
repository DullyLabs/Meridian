import Foundation
import SwiftUI

struct Coordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

/// Where the sun is, and the sky colour that goes with it.
enum Sky {
    /// The sun's height above the horizon in degrees (negative below it), using the US Naval Observatory's low-precision
    /// formulas: https://aa.usno.navy.mil/faq/sun_approx
    static func elevation(at date: Date, _ place: Coordinate) -> Double {
        let rad = Double.pi / 180
        let d = date.timeIntervalSince1970 / 86400 - 10957.5 // days since J2000.0
        let g = (357.529 + 0.98560028 * d) * rad
        let l = (280.459 + 0.98564736 * d + 1.915 * sin(g) + 0.020 * sin(2 * g)) * rad
        let e = (23.439 - 0.00000036 * d) * rad
        let rightAscension = atan2(cos(e) * sin(l), cos(l))
        let declination = asin(sin(e) * sin(l))
        let siderealDegrees = (18.697374558 + 24.06570982441908 * d) * 15
        let hourAngle = (siderealDegrees + place.longitude) * rad - rightAscension
        let latitude = place.latitude * rad
        return asin(sin(latitude) * sin(declination) + cos(latitude) * cos(declination) * cos(hourAngle)) / rad
    }

    /// Black at night, through ember and orange at sunrise and sunset, to the warm yellow of the sun high in the sky.
    private static let stops: [(elevation: Double, rgb: (Double, Double, Double))] = [
        (-18, (0.05, 0.05, 0.06)), (-12, (0.10, 0.08, 0.07)), (-6, (0.26, 0.14, 0.07)), (-2, (0.55, 0.27, 0.09)),
        (2, (0.85, 0.45, 0.13)), (10, (0.97, 0.63, 0.22)), (25, (1.0, 0.76, 0.36)), (60, (1.0, 0.84, 0.50)),
    ]

    static func rgb(_ elevation: Double) -> (Double, Double, Double) {
        guard let upper = stops.firstIndex(where: { $0.elevation >= elevation }) else { return stops.last!.rgb }
        guard upper > 0 else { return stops[0].rgb }
        let (a, b) = (stops[upper - 1], stops[upper])
        let t = (elevation - a.elevation) / (b.elevation - a.elevation)
        return (a.rgb.0 + (b.rgb.0 - a.rgb.0) * t, a.rgb.1 + (b.rgb.1 - a.rgb.1) * t, a.rgb.2 + (b.rgb.2 - a.rgb.2) * t)
    }

    /// The sky colour, and whether black text has more contrast on it than white (WCAG relative luminance above 0.179).
    static func color(_ elevation: Double) -> (color: Color, isBright: Bool) {
        let (r, g, b) = rgb(elevation)
        let linear = { (c: Double) in c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return (Color(red: r, green: g, blue: b), 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b) > 0.179)
    }

    /// The zone's main city from the system's time zone table, or the point on the equator whose solar time matches
    /// the zone's standard offset (for UTC and zones the table lacks).
    static func coordinate(for zone: TimeZone) -> Coordinate {
        let id = zone.identifier
        return zoneTable[id] ?? links[id].flatMap { zoneTable[$0] }
            ?? Coordinate(latitude: 0, longitude: Double(zone.secondsFromGMT() - Int(zone.daylightSavingTimeOffset())) / 240)
    }

    /// Old names for zones, like Asia/Calcutta for Asia/Kolkata, from the "L target link" lines of the system's tz data.
    static let links: [String: String] = {
        guard let text = try? String(contentsOfFile: "/usr/share/zoneinfo/tzdata.zi", encoding: .utf8) else { return [:] }
        return Dictionary(text.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: " ")
            return fields.count == 3 && fields[0] == "L" ? (String(fields[2]), String(fields[1])) : nil
        }, uniquingKeysWith: { first, _ in first })
    }()

    /// Rows of /usr/share/zoneinfo/zone.tab look like "LK	+0656+07951	Asia/Colombo": ±DDMM[SS]±DDDMM[SS].
    private static let zoneTable: [String: Coordinate] = {
        guard let text = try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8) else { return [:] }
        func degrees(_ s: Substring, _ width: Int) -> Double {
            let digits = s.dropFirst().map { Double(String($0))! }
            let number = { (from: Int, count: Int) in digits.dropFirst(from).prefix(count).reduce(0) { $0 * 10 + $1 } }
            let value = number(0, width) + number(width, 2) / 60 + number(width + 2, 2) / 3600
            return s.first == "-" ? -value : value
        }
        var table: [String: Coordinate] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let fields = line.split(separator: "\t")
            guard fields.count >= 3, let split = fields[1].dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }) else { continue }
            table[String(fields[2])] = Coordinate(latitude: degrees(fields[1][..<split], 2), longitude: degrees(fields[1][split...], 3))
        }
        return table
    }()
}
