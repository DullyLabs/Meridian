import SwiftUI

/// The menu bar shows the second city's time, since the first is usually this Mac's own, which the menu bar already shows.
struct MenuBarLabel: View {
    @AppStorage("cities") private var stored = City.defaultIDs
    @AppStorage("twelveHour") private var twelveHour = CityTime.uses12Hour(.autoupdatingCurrent)

    @State private var minute = Self.minute(.now)

    var body: some View {
        Group {
            if let title = Self.title(City.list(stored), date: minute, twelveHour: twelveHour) {
                Text(title).monospacedDigit()
            } else {
                Image(systemName: "globe")
            }
        }
        // A TimelineView here redraws the status item endlessly and hangs the app at launch, so sleep to each minute instead.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.secondsToNextMinute(.now)))
                minute = Self.minute(.now)
            }
        }
    }

    nonisolated static func secondsToNextMinute(_ date: Date) -> TimeInterval {
        Calendar.current.dateInterval(of: .minute, for: date)!.end.timeIntervalSince(date)
    }

    private static func minute(_ date: Date) -> Date { Calendar.current.dateInterval(of: .minute, for: date)!.start }

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
            VStack(spacing: 0) {
                Button("Open Meridian") {
                    DesktopWidget.shared.openMainWindow = { openWindow(id: "main") }
                    DesktopWidget.shared.openMeridian()
                    dismiss()
                }
                Button("Quit Meridian") { NSApp.terminate(nil) }
            }
            .buttonStyle(MenuRowStyle())
        }
        // Narrower and 12-hour labels like "12a" no longer fit their hour cells.
        .frame(width: 600)
        .padding(10)
    }
}

/// A menu item: the whole row is clickable and highlights under the pointer.
private struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Row(configuration: configuration) }

    private struct Row: View {
        let configuration: Configuration
        @State private var hovered = false

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .foregroundStyle(hovered ? Color.white : .primary)
                .background(hovered ? Color.accentColor : .clear, in: .rect(cornerRadius: 5))
                .contentShape(.rect)
                .onHover { hovered = $0 }
        }
    }
}
