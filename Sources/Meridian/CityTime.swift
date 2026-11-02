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
        dayLabel = [Self.dayName(days), TimeGrid.offset(offset)].compactMap { $0 }.joined(separator: " · ")
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

}
