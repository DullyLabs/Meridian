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
        let now = columns.lastIndex { $0 <= date }
        let locale = Locale(identifier: twelveHour ? "en_US" : "en_GB")
        VStack(spacing: 4) {
            ForEach(cities) { city in
                ClockRow(time: CityTime(city: city, date: date, localZone: home, locale: locale),
                         cells: TimeGrid.cells(in: city.timeZone, columns: columns), now: now, twelveHour: twelveHour)
            }
        }
    }
}

struct ClockRow: View {
    let time: CityTime
    let cells: [HourCell]
    let now: Int?
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
    let now: Int?
    let twelveHour: Bool

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                HourCellView(cell: cell, previous: index > 0 ? cells[index - 1] : nil, isNow: index == now, twelveHour: twelveHour, large: false)
            }
        }
        .frame(height: 32)
    }
}

/// An hour coloured by band, with the minutes for zones off the hour. Its leading edge marks a new local day (white or
/// black) or a daylight saving jump (orange); an orange outline marks the current hour. The main grid adds the weekday
/// on a new day.
struct HourCellView: View {
    let cell: HourCell
    let previous: HourCell?
    let isNow: Bool
    let twelveHour: Bool
    let large: Bool

    var body: some View {
        let ink = cell.band == .work ? Color.black : .white
        VStack(spacing: 0) {
            if large { Text(cell.newDay ? cell.weekday : " ").font(.system(size: 9, weight: .bold)) }
            Text(cell.label(twelveHour: twelveHour)).font(.system(size: large ? 16 : 11, weight: .semibold).monospacedDigit())
            if large || cell.minute != 0 { Text(cell.minute == 0 ? " " : String(format: "%02d", cell.minute)).font(.system(size: large ? 9 : 8)) }
        }
        .foregroundStyle(ink)
        .minimumScaleFactor(0.5).lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cell.band.color, in: .rect(cornerRadius: 3))
        .overlay(alignment: .leading) {
            if let previous {
                if cell.newDay { Rectangle().fill(ink.opacity(0.85)).frame(width: 2) }
                else if (cell.hour - previous.hour + 24) % 24 != 1 { Rectangle().fill(.orange).frame(width: 2) }
            }
        }
        .overlay { if isNow { RoundedRectangle(cornerRadius: 3).strokeBorder(.orange, lineWidth: 2) } }
        .help(cell.date.formatted(Date.FormatStyle(timeZone: cell.zone).weekday(.wide).month(.abbreviated).day().hour().minute()))
    }
}
