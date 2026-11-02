import Foundation

/// What one clock shows for a city at a moment, formatted for the user's locale and 12/24-hour setting.
struct CityTime {
    let name: String
    let time: String
    let period: String?
    let dayLabel: String

    init(city: City, date: Date, localZone: TimeZone = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) {
        let zone = city.timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        calendar.locale = locale
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: zone)

        name = city.displayName
        time = date.formatted(style.hour(.defaultDigits(amPM: .omitted)).minute())
        period = Self.uses12Hour(locale) ? (calendar.component(.hour, from: date) < 12 ? calendar.amSymbol : calendar.pmSymbol) : nil

        let offset = zone.secondsFromGMT(for: date) - localZone.secondsFromGMT(for: date)
        var localCalendar = calendar
        localCalendar.timeZone = localZone
        let days = localCalendar.dateComponents(
            [.day], from: localCalendar.startOfDay(for: date), to: localCalendar.startOfDay(for: date + Double(offset))
        ).day ?? 0
        dayLabel = [Self.dayName(days), Self.offsetName(offset)].compactMap { $0 }.joined(separator: " · ")
    }

    static func uses12Hour(_ locale: Locale) -> Bool {
        DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale)?.contains("a") ?? false
    }

    private static func dayName(_ days: Int) -> String {
        switch days {
        case ..<0: "Yesterday"
        case 0: "Today"
        default: "Tomorrow"
        }
    }

    /// +3h, −5h30, or nil when the city shares the local time.
    private static func offsetName(_ seconds: Int) -> String? {
        guard seconds != 0 else { return nil }
        let sign = seconds > 0 ? "+" : "\u{2212}"
        let minutes = abs(seconds) / 60
        return minutes % 60 == 0 ? "\(sign)\(minutes / 60)h" : "\(sign)\(minutes / 60)h\(String(format: "%02d", minutes % 60))"
    }
}
