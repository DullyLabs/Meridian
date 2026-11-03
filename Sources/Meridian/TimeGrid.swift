import Foundation

/// One zone's local time at one grid column.
struct HourCell: Identifiable {
    let date: Date
    let zone: TimeZone
    let hour: Int
    let minute: Int
    /// The local calendar day differs from the previous column (always true for the first column).
    let newDay: Bool
    /// The sun's elevation in degrees halfway through the hour.
    let elevation: Double
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

    static func cells(in zone: TimeZone, columns: [Date], at place: Coordinate) -> [HourCell] {
        let calendar = calendar(zone)
        var previousDay: Int?
        return columns.map { date in
            let parts = calendar.dateComponents([.day, .hour, .minute], from: date)
            defer { previousDay = parts.day }
            return HourCell(date: date, zone: zone, hour: parts.hour!, minute: parts.minute!, newDay: parts.day != previousDay,
                            elevation: Sky.elevation(at: date + 1800, place))
        }
    }

    /// Where `date` falls as a fractional column index, e.g. 9.25 a quarter of the way through column 9.
    static func position(of date: Date, in columns: [Date]) -> Double? {
        guard let index = columns.lastIndex(where: { $0 <= date }), date < columns[index] + 3600 else { return nil }
        return Double(index) + date.timeIntervalSince(columns[index]) / 3600
    }

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
