import ServiceManagement
import SwiftUI

/// Compare up to five time zones hour by hour, like World Time Buddy. The first zone is the home zone.
@main
struct MeridianApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @AppStorage("showWidget") private var showWidget = true
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some Scene {
        Window("Meridian", id: "main") {
            TimeGridView().frame(minWidth: 960, minHeight: 420)
                .onAppear { if showWidget { DesktopWidget.shared.show() } }
                .onChange(of: showWidget) { $1 ? DesktopWidget.shared.show() : DesktopWidget.shared.hide() }
                .onChange(of: openAtLogin) { _, on in
                    try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    openAtLogin = SMAppService.mainApp.status == .enabled
                }
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Toggle("Desktop Widget", isOn: $showWidget).keyboardShortcut("d")
                Toggle("Open at Login", isOn: $openAtLogin)
            }
        }
    }
}

/// Closing the window keeps the app running so the desktop widget stays up.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct TimeGridView: View {
    static let limit = 5
    private static let rowHeight: CGFloat = 52

    @AppStorage("cities") private var stored = City.defaults.map(\.id).joined(separator: "\n")
    @AppStorage("twelveHour") private var twelveHour = CityTime.uses12Hour(.autoupdatingCurrent)
    @State private var dayOffset = 0
    @State private var hovered: Int?
    @State private var drag: (from: Int, to: Int)?
    @State private var adding = false

    private var cities: [City] { stored.split(separator: "\n").compactMap { City(id: String($0)) } }
    private func save(_ cities: [City]) { stored = cities.map(\.id).joined(separator: "\n") }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let cities = cities
            let columns = TimeGrid.dayColumns(home: cities.first?.timeZone ?? .current, date: context.date, days: dayOffset)
            let now = columns.firstIndex { $0 <= context.date && context.date < $0 + 3600 }
            let range = drag.map { min($0.from, $0.to)...max($0.from, $0.to) } ?? (hovered ?? now).map { $0...$0 }
            VStack(spacing: 10) {
                toolbar(cities: cities, columns: columns)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(spacing: 4) {
                        ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
                            info(index: index, city: city, cities: cities, columns: columns, range: range)
                        }
                    }
                    .frame(width: 400)
                    timeline(cities: cities, columns: columns, now: now, range: range)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private func toolbar(cities: [City], columns: [Date]) -> some View {
        HStack {
            Button("Today") { dayOffset = 0 }.disabled(dayOffset == 0)
            Button { dayOffset -= 1 } label: { Image(systemName: "chevron.left") }
            Button { dayOffset += 1 } label: { Image(systemName: "chevron.right") }
            Text(columns[0].formatted(Date.FormatStyle(timeZone: cities.first?.timeZone ?? .current).weekday(.wide).day().month(.wide)))
                .font(.headline)
            Spacer()
            Picker("", selection: $twelveHour) { Text("am pm").tag(true); Text("24").tag(false) }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
            Button("Add City", systemImage: "plus") { adding = true }
                .disabled(cities.count >= Self.limit)
                .popover(isPresented: $adding) { CityPicker { save(cities + [$0]); adding = false } }
        }
    }

    /// Left and middle columns: offset to home, city, and the selected range in that zone.
    private func info(index: Int, city: City, cities: [City], columns: [Date], range: ClosedRange<Int>?) -> some View {
        let zone = city.timeZone
        let home = cities[0].timeZone
        let offset = Double(zone.secondsFromGMT(for: columns[0]) - home.secondsFromGMT(for: columns[0])) / 3600
        return HStack(spacing: 8) {
            Group {
                if index == 0 { Image(systemName: "house.fill") } else { Text(offset.formatted(.number.sign(strategy: .always(includingZero: false)))) }
            }
            .frame(width: 40).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(city.displayName).font(.headline).lineLimit(1)
                Text(TimeGrid.utcOffset(zone, at: columns[0])).font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 130, alignment: .leading)
            if let range {
                let start = columns[range.lowerBound], end = columns[range.upperBound] + 3600
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(clock(start, zone)) - \(clock(end, zone))").font(.system(size: 15, weight: .semibold).monospacedDigit())
                    Text(Set([start, end - 1]).sorted().map { $0.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated).month(.abbreviated).day()) }.joined(separator: "   "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Move Up") { move(index, by: -1, in: cities) }.disabled(index == 0)
                Button("Move Down") { move(index, by: 1, in: cities) }.disabled(index == cities.count - 1)
                Button("Remove", role: .destructive) { save(cities.filter { $0.id != city.id }) }.disabled(cities.count == 1)
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).fixedSize()
        }
        .frame(height: Self.rowHeight)
    }

    private func clock(_ date: Date, _ zone: TimeZone) -> String {
        let style = Date.FormatStyle(locale: Locale(identifier: twelveHour ? "en_US" : "en_GB"), timeZone: zone)
        return date.formatted(twelveHour ? style.hour(.defaultDigits(amPM: .abbreviated)).minute() : style.hour(.twoDigits(amPM: .omitted)).minute())
    }

    private func timeline(cities: [City], columns: [Date], now: Int?, range: ClosedRange<Int>?) -> some View {
        VStack(spacing: 4) {
            ForEach(cities) { city in
                HStack(spacing: 1) {
                    ForEach(TimeGrid.cells(in: city.timeZone, columns: columns)) { tile($0, isNow: $0.date == now.map { columns[$0] }) }
                }
                .frame(height: Self.rowHeight)
            }
        }
        .overlay {
            GeometryReader { proxy in
                let width = proxy.size.width / CGFloat(columns.count)
                if let range {
                    let x = width * CGFloat(range.lowerBound)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(.green, lineWidth: 3)
                        .frame(width: width * CGFloat(range.count)).offset(x: x)
                    Text("\u{2190} \(range.count) hour\(range.count == 1 ? "" : "s") \u{2192}").font(.caption.bold()).foregroundStyle(.green)
                        .position(x: x + width * CGFloat(range.count) / 2, y: -10)
                }
                Color.clear.contentShape(.rect)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let column = { (x: CGFloat) in min(max(Int(x / width), 0), columns.count - 1) }
                        drag = (column(value.startLocation.x), column(value.location.x))
                    })
                    .onContinuousHover { phase in
                        if case .active(let point) = phase { hovered = min(max(Int(point.x / width), 0), columns.count - 1) } else { hovered = nil }
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tile(_ cell: HourCell, isNow: Bool) -> some View {
        VStack(spacing: 0) {
            Text(cell.newDay ? cell.weekday : " ").font(.system(size: 8, weight: .bold))
            Text(cell.newDay ? cell.dateTag : cell.label(twelveHour: twelveHour))
                .font(.system(size: cell.newDay ? 11 : 16, weight: .semibold).monospacedDigit())
            Text(cell.minute == 0 ? " " : String(format: "%02d", cell.minute)).font(.system(size: 8))
        }
        .foregroundStyle(cell.band == .work ? Color.black : .white)
        .minimumScaleFactor(0.5).lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cell.band.color, in: .rect(cornerRadius: 3))
        .overlay { if isNow { RoundedRectangle(cornerRadius: 3).strokeBorder(.orange, lineWidth: 2) } }
    }

    private func move(_ index: Int, by step: Int, in cities: [City]) {
        var cities = cities
        cities.swapAt(index, index + step)
        save(cities)
    }
}

private struct CityPicker: View {
    let pick: (City) -> Void
    @State private var query = ""

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search cities", text: $query).textFieldStyle(.roundedBorder)
            List(City.search(query).prefix(50)) { city in
                Button(city.name) { pick(city) }.buttonStyle(.plain)
            }
        }
        .padding(12).frame(width: 260, height: 320)
    }
}
