import SwiftUI

/// The menu bar shows the second city's time, since the first is usually this Mac's own, which the menu bar already shows.
struct MenuBarLabel: View {
    @AppStorage("cities") private var stored = City.defaultIDs
    @AppStorage("twelveHour") private var twelveHour = CityTime.uses12Hour(.autoupdatingCurrent)

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let title = Self.title(City.list(stored), date: context.date, twelveHour: twelveHour) {
                Text(title).monospacedDigit()
            } else {
                Image(systemName: "globe")
            }
        }
    }

    /// "NY 09:41", or nil with only one city.
    nonisolated static func title(_ cities: [City], date: Date, twelveHour: Bool) -> String? {
        guard cities.count > 1 else { return nil }
        let city = cities[1]
        return "\(city.shortName) \(TimeGrid.clock(date, city.timeZone, twelveHour: twelveHour))"
    }
}

/// The menu bar clock's window: the widget's clocks, then ways back to the app.
struct MenuBarClockView: View {
    @AppStorage("cities") private var stored = City.defaultIDs
    @AppStorage("twelveHour") private var twelveHour = CityTime.uses12Hour(.autoupdatingCurrent)
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.everyMinute) { context in
                WorldClockView(date: context.date, cities: City.list(stored), twelveHour: twelveHour)
            }
            Divider()
            Group {
                Button("Open Meridian") {
                    DesktopWidget.shared.openMainWindow = { openWindow(id: "main") }
                    DesktopWidget.shared.openMeridian()
                    dismiss()
                }
                Button("Quit Meridian") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        // Narrower and 12-hour labels like "12a" no longer fit their hour cells.
        .frame(width: 600)
        .padding(10)
    }
}
