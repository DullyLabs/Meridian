import SwiftUI

/// How comfortable an hour is to be awake in: daytime, early morning or evening, or night.
enum Band {
    case work, edge, night

    init(hour: Int) {
        switch hour {
        case 8..<18: self = .work
        case 6..<8, 18..<22: self = .edge
        default: self = .night
        }
    }

    var color: Color {
        switch self {
        case .work: Color(white: 0.8)
        case .edge: Color(red: 0.36, green: 0.42, blue: 0.53)
        case .night: Color(red: 0.10, green: 0.14, blue: 0.30)
        }
    }
}

/// One zone's local time at one grid column.
struct HourCell: Identifiable {
    let date: Date
    let zone: TimeZone
    let hour: Int
    let minute: Int
    /// The local calendar day differs from the previous column (always true for the first column).
    let newDay: Bool
    var band: Band { Band(hour: hour) }
    var id: Date { date }
    /// "MON", in the zone's own calendar.
    var weekday: String { date.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated)).uppercased() }

    /// "14" or "2p".
    func label(twelveHour: Bool) -> String {
        twelveHour ? "\(hour % 12 == 0 ? 12 : hour % 12)\(hour < 12 ? "a" : "p")" : String(format: "%02d", hour)
    }
}

enum TimeGrid {
    /// Hourly columns from 00:00 to 00:00 in the home zone on the day containing `date`, shifted by `days`.
    /// Daylight saving days have 23 or 25 columns.
    static func dayColumns(home: TimeZone, date: Date, days: Int = 0) -> [Date] {
        let calendar = calendar(home)
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: days, to: date)!)
        return Array(stride(from: start, to: calendar.date(byAdding: .day, value: 1, to: start)!, by: 3600))
    }

    private static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    static func cells(in zone: TimeZone, columns: [Date]) -> [HourCell] {
        let calendar = calendar(zone)
        var previousDay: Int?
        return columns.map { date in
            let parts = calendar.dateComponents([.day, .hour, .minute], from: date)
            defer { previousDay = parts.day }
            return HourCell(date: date, zone: zone, hour: parts.hour!, minute: parts.minute!, newDay: parts.day != previousDay)
        }
    }

    /// "9:00 AM" or "09:00".
    static func clock(_ date: Date, _ zone: TimeZone, twelveHour: Bool) -> String {
        let style = Date.FormatStyle(locale: locale(twelveHour), timeZone: zone)
        return date.formatted(twelveHour ? style.hour(.defaultDigits(amPM: .abbreviated)).minute() : style.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// One line per city for pasting into an invite: "London: Mon, Nov 3, 9:00 AM", plus " - 10:00 AM" when given an
    /// end, with the end's day too when it falls on another day. Plain spaces, since some apps mangle the narrow one before AM.
    static func summary(_ cities: [City], start: Date, end: Date?, twelveHour: Bool) -> String {
        cities.map { city in
            let zone = city.timeZone
            let day = { (date: Date) in date.formatted(Date.FormatStyle(locale: locale(twelveHour), timeZone: zone).weekday(.abbreviated).month(.abbreviated).day()) }
            var line = "\(city.displayName): \(day(start)), \(clock(start, zone, twelveHour: twelveHour))"
            if let end {
                line += " - " + (day(end - 1) == day(start) ? "" : "\(day(end)), ") + clock(end, zone, twelveHour: twelveHour)
            }
            return line
        }
        .joined(separator: "\n")
        .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private static func locale(_ twelveHour: Bool) -> Locale { Locale(identifier: twelveHour ? "en_US" : "en_GB") }

    /// "UTC+5:30", "UTC-8" or "UTC".
    static func utcOffset(_ zone: TimeZone, at date: Date) -> String {
        "UTC" + (offset(zone.secondsFromGMT(for: date)) ?? "")
    }

    /// "+5:30", "−7", or nil for no offset.
    static func offset(_ seconds: Int) -> String? {
        let minutes = seconds / 60
        guard minutes != 0 else { return nil }
        let sign = minutes > 0 ? "+" : "\u{2212}"
        return "\(sign)\(abs(minutes) / 60)" + (minutes % 60 == 0 ? "" : String(format: ":%02d", abs(minutes) % 60))
    }
}
