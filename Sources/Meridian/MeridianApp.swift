import ServiceManagement
import SwiftUI

/// Compare up to five time zones hour by hour, like World Time Buddy. The first zone is the home zone.
@main
struct MeridianApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @AppStorage("showWidget") private var showWidget = true
    @State private var openAtLogin = Self.loginItemOn

    var body: some Scene {
        Window("Meridian", id: "main") {
            TimeGridView().frame(minWidth: 960, minHeight: 420)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in openAtLogin = Self.loginItemOn }
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Toggle("Desktop Widget", isOn: Binding(get: { showWidget }, set: { showWidget = $0; DesktopWidget.shared.setVisible($0) }))
                    .keyboardShortcut("d")
                Toggle("Open at Login", isOn: Binding(get: { openAtLogin }, set: setOpenAtLogin))
            }
        }
    }

    /// Registered counts as on even while it waits for approval, so the toggle can still turn it off.
    private static var loginItemOn: Bool { [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) }

    /// An ad hoc signed app may need approving in System Settings › Login Items, so open it there when asked.
    private func setOpenAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        try? on ? service.register() : service.unregister()
        if on && service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        openAtLogin = Self.loginItemOn
    }
}

/// Shows the widget at launch, and keeps the app running when the window closes so the widget stays up.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: "showWidget") as? Bool ?? true { DesktopWidget.shared.setVisible(true) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct TimeGridView: View {
    static let limit = 5
    private static let rowHeight: CGFloat = 52

    @AppStorage("cities") private var stored = City.defaults.map(\.id).joined(separator: "\n")
    @AppStorage("twelveHour") private var twelveHour = CityTime.uses12Hour(.autoupdatingCurrent)
    @Environment(\.openWindow) private var openWindow
    @State private var dayOffset = 0
    @State private var hovered: Int?
    @State private var drag: (from: Int, to: Int)?
    @State private var lastClick: Int?
    @State private var adding = false

    private var cities: [City] { stored.split(separator: "\n").compactMap { City(id: String($0)) } }
    private func save(_ cities: [City]) { stored = cities.map(\.id).joined(separator: "\n") }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let cities = cities
            let columns = TimeGrid.dayColumns(home: cities.first?.timeZone ?? .current, date: context.date, days: dayOffset)
            let position = TimeGrid.position(of: context.date, in: columns)
            let now = position.map { Int($0) }
            // Clamped, since a selection made on a longer day can outlast it (daylight saving days have 23 or 25 columns).
            let range = (drag.map { min($0.from, $0.to)...max($0.from, $0.to) } ?? (hovered ?? now).map { $0...$0 })?
                .clamped(to: 0...(columns.count - 1))
            VStack(spacing: 10) {
                toolbar(cities: cities, columns: columns)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(spacing: 4) {
                        ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
                            info(index: index, city: city, cities: cities, columns: columns, range: range)
                        }
                    }
                    .frame(width: 400)
                    timeline(cities: cities, columns: columns, now: position, range: range)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .onAppear {
            DesktopWidget.shared.openMainWindow = { openWindow(id: "main") }
            DesktopWidget.shared.updateDockIcon()
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
        let offset = zone.secondsFromGMT(for: columns[0]) - home.secondsFromGMT(for: columns[0])
        return HStack(spacing: 8) {
            Group {
                if index == 0 { Image(systemName: "house.fill") } else { Text(TimeGrid.offset(offset) ?? "0") }
            }
            .frame(width: 56).foregroundStyle(.secondary).lineLimit(1)
            VStack(alignment: .leading, spacing: 1) {
                Text(city.displayName).font(.headline).lineLimit(1)
                if city.zone != "UTC" { Text(TimeGrid.utcOffset(zone, at: columns[0])).font(.caption).foregroundStyle(.secondary) }
            }
            .frame(width: 130, alignment: .leading)
            if let range {
                let start = columns[range.lowerBound], end = columns[range.upperBound] + 3600
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(clock(start, zone)) - \(clock(end, zone))").font(.system(size: 15, weight: .semibold).monospacedDigit())
                    let days = [start, end - 1].map { $0.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated).month(.abbreviated).day()) }
                    Text(days[0] == days[1] ? days[0] : days.joined(separator: " \u{2192} "))
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

    private func clock(_ date: Date, _ zone: TimeZone) -> String { TimeGrid.clock(date, zone, twelveHour: twelveHour) }

    private func copy(_ cities: [City], start: Date, end: Date?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(TimeGrid.summary(cities, start: start, end: end, twelveHour: twelveHour), forType: .string)
    }

    private func timeline(cities: [City], columns: [Date], now: Double?, range: ClosedRange<Int>?) -> some View {
        VStack(spacing: 4) {
            ForEach(cities) { city in
                HStack(spacing: HourCellView.gap) {
                    let cells = TimeGrid.cells(in: city.timeZone, columns: columns, at: city.coordinate)
                    ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                        HourCellView(cell: cell, previous: index > 0 ? cells[index - 1] : nil, isNow: index == now.map { Int($0) }, twelveHour: twelveHour, large: true)
                    }
                }
                .frame(height: Self.rowHeight)
            }
        }
        .overlay {
            GeometryReader { proxy in
                let width = proxy.size.width / CGFloat(columns.count)
                if let range {
                    let x = width * CGFloat(range.lowerBound)
                    RoundedRectangle(cornerRadius: 4).strokeBorder(.primary, lineWidth: 2.5)
                        .frame(width: width * CGFloat(range.count)).offset(x: x)
                }
                Color.clear.contentShape(.rect)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let column = { (x: CGFloat) in min(max(Int(x / width), 0), columns.count - 1) }
                            drag = (column(value.startLocation.x), column(value.location.x))
                        }
                        // Clicking the single selected hour again clears the selection.
                        .onEnded { _ in
                            if let drag, drag.from == drag.to, drag.from == lastClick { self.drag = nil; lastClick = nil }
                            else { lastClick = drag.flatMap { $0.from == $0.to ? $0.from : nil } }
                        })
                    .onContinuousHover { phase in
                        if case .active(let point) = phase { hovered = min(max(Int(point.x / width), 0), columns.count - 1) } else { hovered = nil }
                    }
                    .contextMenu {
                        if let range {
                            let start = columns[range.lowerBound], end = columns[range.upperBound] + 3600
                            Button("Copy Start Time") { copy(cities, start: start, end: nil) }
                            Button("Copy Start and End Times") { copy(cities, start: start, end: end) }
                        }
                    }
            }
        }
        .nowColumn()
        .overlay { NowLine(position: now, columns: columns.count) }
        .overlay {
            // The selection's length, above the now line so the line never runs through it.
            GeometryReader { proxy in
                if let range {
                    let width = proxy.size.width / CGFloat(columns.count)
                    Text("\(range.count) hour\(range.count == 1 ? "" : "s")").font(.caption2.bold()).foregroundStyle(Color(nsColor: .windowBackgroundColor))
                        .padding(.horizontal, 6).padding(.vertical, 1).background(.primary, in: .capsule).fixedSize()
                        .position(x: width * (CGFloat(range.lowerBound) + CGFloat(range.count) / 2), y: 0)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
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
