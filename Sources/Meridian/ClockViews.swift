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
                HourCellView(cell: cell, previous: index > 0 ? cells[index - 1] : nil, isNow: index == now.map { Int($0) }, twelveHour: twelveHour, large: false)
            }
        }
        .overlay { NowLine(position: now, columns: cells.count) }
        .frame(height: 32)
    }
}

/// A blue line at the current time, `position` columns from the left edge.
struct NowLine: View {
    let position: Double?
    let columns: Int

    var body: some View {
        GeometryReader { proxy in
            if let position {
                // A dark halo keeps it visible on the yellow cells.
                Rectangle().fill(Color.now).frame(width: 2).padding(.horizontal, 1).background(.black.opacity(0.6))
                    .offset(x: proxy.size.width * position / Double(columns) - 2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// An hour coloured by the sun at that place and time, with the minutes for zones off the hour. A line in the gap before it
/// marks a new local day (solid) or a daylight saving jump (dashed). A blue outline marks the current hour, and the main
/// grid adds the weekday on a new day.
struct HourCellView: View {
    static let gap: CGFloat = 2

    let cell: HourCell
    let previous: HourCell?
    let isNow: Bool
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
        .overlay {
            if isNow {
                RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.6), lineWidth: 4)
                    .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Color.now, lineWidth: 2) }
            }
        }
        .help(cell.date.formatted(Date.FormatStyle(timeZone: cell.zone).weekday(.wide).month(.abbreviated).day().hour().minute()))
    }
}

/// A vertical line through the middle of its frame.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { $0.move(to: CGPoint(x: rect.midX, y: rect.minY)); $0.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)) }
    }
}
