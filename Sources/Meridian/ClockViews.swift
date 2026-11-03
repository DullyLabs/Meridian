import SwiftUI

/// Digital clocks for up to five cities, one per row, each with the home zone's day, 00:00 to 00:00, as a colour-banded strip.
/// Days and offsets are relative to the first city, the home zone, as in the main window.
struct WorldClockView: View {
    let date: Date
    let cities: [City]
    let twelveHour: Bool

    var body: some View {
        let home = cities.first?.timeZone ?? .autoupdatingCurrent
        let columns = TimeGrid.dayColumns(home: home, date: date)
        let now = TimeGrid.position(of: date, in: columns)
        let locale = Locale(identifier: twelveHour ? "en_US" : "en_GB")
        VStack(spacing: 4) {
            ForEach(cities) { city in
                ClockRow(time: CityTime(city: city, date: date, localZone: home, locale: locale),
                         cells: TimeGrid.cells(in: city.timeZone, columns: columns, at: city.coordinate), now: now, twelveHour: twelveHour)
            }
        }
        .nowColumn()
    }
}

struct ClockRow: View {
    let time: CityTime
    let cells: [HourCell]
    let now: Double?
    let twelveHour: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(time.name).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                Text(time.dayLabel).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.85)
            }
            .frame(width: 84, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(time.time).font(.system(size: 18, weight: .semibold, design: .rounded)).contentTransition(.numericText())
                if let period = time.period { Text(period).font(.system(size: 9, weight: .bold, design: .rounded)).opacity(0.75) }
            }
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: 70, alignment: .leading)
            HourStrip(cells: cells, now: now, twelveHour: twelveHour)
        }
        .frame(height: 44)
        .padding(.horizontal, 6)
        .background(.fill.quaternary, in: .rect(cornerRadius: 8))
    }
}

/// One row of hour cells for the widget.
struct HourStrip: View {
    let cells: [HourCell]
    let now: Double?
    let twelveHour: Bool

    var body: some View {
        HStack(spacing: HourCellView.gap) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                HourCellView(cell: cell, previous: index > 0 ? cells[index - 1] : nil, now: TimeGrid.fraction(now, in: index), twelveHour: twelveHour, large: false)
            }
        }
        .frame(height: 32)
    }
}

/// An hour coloured by the sun at that place and time, with the minutes for zones off the hour. A line in the gap before it
/// marks a new local day (solid) or a daylight saving jump (dashed). The current hour draws a line at the current minute
/// in its text colour, so it contrasts with the cell, and reports its bounds so `nowColumn()` can outline that column
/// across every row. The main grid adds the weekday on a new day.
struct HourCellView: View {
    static let gap: CGFloat = 2

    let cell: HourCell
    let previous: HourCell?
    /// How far through this hour the current time is, 0 to 1, when this is the current hour.
    let now: Double?
    let twelveHour: Bool
    let large: Bool

    var body: some View {
        let sky = Sky.color(cell.elevation)
        let ink = sky.isBright ? Color.black : .white
        VStack(spacing: 0) {
            if large { Text(cell.newDay ? cell.weekday : " ").font(.system(size: 9, weight: .bold)) }
            Text(cell.label(twelveHour: twelveHour)).font(.system(size: large ? 16 : 11, weight: .semibold).monospacedDigit())
            if large || cell.minute != 0 { Text(cell.minute == 0 ? " " : String(format: "%02d", cell.minute)).font(.system(size: large ? 9 : 8)) }
        }
        .foregroundStyle(ink)
        .minimumScaleFactor(0.5).lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sky.color, in: .rect(cornerRadius: 3))
        .overlay(alignment: .leading) {
            // Drawn in the gap, outside the cell, so every cell keeps the same width.
            if let previous, cell.newDay || (cell.hour - previous.hour + 24) % 24 != 1 {
                Line()
                    .stroke(.primary.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: cell.newDay ? [] : [3, 2]))
                    .frame(width: 1.5).padding(.vertical, -3)
                    .offset(x: -(Self.gap + 1.5) / 2)
            }
        }
        .overlay(alignment: .leading) {
            if let now {
                GeometryReader { proxy in
                    Rectangle().fill(ink).frame(width: 2).offset(x: proxy.size.width * now - 1)
                }
            }
        }
        .anchorPreference(key: NowCells.self, value: .bounds) { now == nil ? [] : [$0] }
        .help(cell.date.formatted(Date.FormatStyle(timeZone: cell.zone).weekday(.wide).month(.abbreviated).day().hour().minute()))
    }
}

/// A vertical line through the middle of its frame.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { $0.move(to: CGPoint(x: rect.midX, y: rect.minY)); $0.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)) }
    }
}

/// The bounds of each row's current-hour cell.
struct NowCells: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) { value += nextValue() }
}

extension View {
    /// One blue outline around the current hour's cells in every row.
    func nowColumn() -> some View {
        overlayPreferenceValue(NowCells.self) { anchors in
            GeometryReader { proxy in
                if let first = anchors.first {
                    let box = anchors.dropFirst().reduce(proxy[first]) { $0.union(proxy[$1]) }.insetBy(dx: -2, dy: -2)
                    RoundedRectangle(cornerRadius: 5).strokeBorder(Color.now, lineWidth: 2.5)
                        .frame(width: box.width, height: box.height).offset(x: box.minX, y: box.minY)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
