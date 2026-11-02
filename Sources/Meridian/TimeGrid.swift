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
        case .edge: Color(red: 0.45, green: 0.52, blue: 0.62)
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
    /// "NOV 2" and "MON", in the zone's own calendar.
    var dateTag: String { date.formatted(Date.FormatStyle(timeZone: zone).month(.abbreviated).day()).uppercased() }
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

    /// `count` hourly columns starting at the home zone's hour containing `date`.
    static func hourly(from date: Date, count: Int, home: TimeZone) -> [Date] {
        let start = calendar(home).dateInterval(of: .hour, for: date)!.start
        return (0..<count).map { start + Double($0 * 3600) }
    }

    private static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    static func cells(in zone: TimeZone, columns: [Date]) -> [HourCell] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var previousDay: Int?
        return columns.map { date in
            let parts = calendar.dateComponents([.day, .hour, .minute], from: date)
            defer { previousDay = parts.day }
            return HourCell(date: date, zone: zone, hour: parts.hour!, minute: parts.minute!, newDay: parts.day != previousDay)
        }
    }

    /// "UTC+5:30", "UTC-8" or "UTC".
    static func utcOffset(_ zone: TimeZone, at date: Date) -> String {
        let minutes = zone.secondsFromGMT(for: date) / 60
        guard minutes != 0 else { return "UTC" }
        let sign = minutes > 0 ? "+" : "\u{2212}"
        return "UTC\(sign)\(abs(minutes) / 60)" + (minutes % 60 == 0 ? "" : String(format: ":%02d", abs(minutes) % 60))
    }
}
