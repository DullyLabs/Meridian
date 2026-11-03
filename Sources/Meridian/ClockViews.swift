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
        HStack(spacing: 1) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                HourCellView(cell: cell, previous: index > 0 ? cells[index - 1] : nil, twelveHour: twelveHour, large: false)
            }
        }
        .overlay { NowLine(position: now, columns: cells.count) }
        .frame(height: 32)
    }
}

/// A red line at the current time, `position` columns from the left edge.
struct NowLine: View {
    let position: Double?
    let columns: Int

    var body: some View {
        GeometryReader { proxy in
            if let position {
                // A dark halo keeps the red visible on the pink, orange and blue cells.
                Rectangle().fill(Color(red: 0.87, green: 0.12, blue: 0.12)).frame(width: 2).padding(.horizontal, 1).background(.black.opacity(0.7))
                    .offset(x: proxy.size.width * position / Double(columns) - 2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// An hour coloured like the sky at that place and time, with the minutes for zones off the hour. Its leading edge marks a
/// new local day (white or black) or a daylight saving jump (orange). The main grid adds the weekday on a new day.
struct HourCellView: View {
    let cell: HourCell
    let previous: HourCell?
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
            if let previous {
                if cell.newDay { Rectangle().fill(ink).frame(width: 3) }
                // Orange edged with the text colour, since orange is also a sky colour.
                else if (cell.hour - previous.hour + 24) % 24 != 1 { Rectangle().fill(.orange).frame(width: 2).padding(.horizontal, 1).background(ink) }
            }
        }
        .help(cell.date.formatted(Date.FormatStyle(timeZone: cell.zone).weekday(.wide).month(.abbreviated).day().hour().minute()))
    }
}
