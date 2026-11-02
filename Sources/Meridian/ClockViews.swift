import SwiftUI

/// Digital clocks for up to five cities, one per row, each with the next 12 hours as a colour-banded strip.
struct WorldClockView: View {
    let date: Date
    let cities: [City]

    var body: some View {
        let columns = TimeGrid.hourly(from: date, count: 12)
        VStack(spacing: 4) {
            ForEach(cities) { city in
                ClockRow(time: CityTime(city: city, date: date), cells: TimeGrid.cells(in: city.timeZone, columns: columns))
            }
        }
    }
}

struct ClockRow: View {
    let time: CityTime
    let cells: [HourCell]

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(time.name).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                Text(time.dayLabel).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.7)
            }
            .frame(width: 84, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(time.time).font(.system(size: 18, weight: .semibold, design: .rounded)).contentTransition(.numericText())
                if let period = time.period { Text(period).font(.system(size: 9, weight: .bold, design: .rounded)).opacity(0.75) }
            }
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: 70, alignment: .leading)
            HourStrip(cells: cells)
        }
        .frame(height: 40)
        .padding(.horizontal, 6)
        .background(.fill.quaternary, in: .rect(cornerRadius: 8))
    }
}

/// Hour labels coloured by band; a new local day is marked by a bright edge.
struct HourStrip: View {
    let cells: [HourCell]
    private let twelveHour = CityTime.uses12Hour(.autoupdatingCurrent)

    var body: some View {
        HStack(spacing: 1) {
            ForEach(cells) { cell in
                Text(cell.label(twelveHour: twelveHour))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(cell.band == .work ? Color.black : .white)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(cell.band.color, in: .rect(cornerRadius: 2))
                    .overlay(alignment: .leading) { if cell.newDay && cell.id != cells.first?.id { Rectangle().fill(.primary).frame(width: 1.5) } }
            }
        }
        .frame(height: 22)
    }
}
