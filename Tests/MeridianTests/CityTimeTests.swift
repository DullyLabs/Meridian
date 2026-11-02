import XCTest
@testable import Meridian

final class CityTimeTests: XCTestCase {
    private let singapore = TimeZone(identifier: "Asia/Singapore")!
    private let us = Locale(identifier: "en_US")
    private let uk = Locale(identifier: "en_GB")
    // 2026-10-29 01:30 in Singapore
    private let date = ISO8601DateFormatter().date(from: "2026-10-28T17:30:00Z")!

    private func time(_ zone: String, locale: Locale) -> CityTime {
        CityTime(city: City(name: City.cityName(zone), zone: zone), date: date, localZone: singapore, locale: locale)
    }

    func testTwelveHourClockSplitsOffThePeriod() {
        let london = time("Europe/London", locale: us)
        XCTAssertEqual(london.time, "5:30")
        XCTAssertEqual(london.period, "PM")
        XCTAssertEqual(london.dayLabel, "Yesterday · \u{2212}8h")
    }

    func testTwentyFourHourClockHasNoPeriod() {
        let london = time("Europe/London", locale: uk)
        XCTAssertEqual(london.time, "17:30")
        XCTAssertNil(london.period)
    }

    func testHalfHourOffsetAndSameDay() {
        XCTAssertEqual(time("Asia/Kolkata", locale: uk).dayLabel, "Yesterday · \u{2212}2h30")
        XCTAssertEqual(time("Asia/Tokyo", locale: uk).dayLabel, "Today · +1h")
        XCTAssertEqual(time("Asia/Singapore", locale: uk).dayLabel, "Today")
    }

    private let utc = TimeZone(identifier: "UTC")!
    private func hours(_ zone: String, day: String, home: TimeZone? = nil) -> [HourCell] {
        let home = home ?? utc
        let columns = TimeGrid.dayColumns(home: home, date: ISO8601DateFormatter().date(from: day)!)
        return TimeGrid.cells(in: TimeZone(identifier: zone)!, columns: columns)
    }

    func testGridHasTwentyFourColumnsFromHomeMidnight() {
        let cells = hours("Asia/Tokyo", day: "2026-06-10T15:00:00Z")
        XCTAssertEqual(cells.count, 24)
        XCTAssertEqual(cells[0].hour, 9)
        XCTAssertEqual(cells[0].date, ISO8601DateFormatter().date(from: "2026-06-10T00:00:00Z"))
    }

    func testHalfHourZoneKeepsMinutesAndDayBoundary() {
        let cells = hours("Asia/Kolkata", day: "2026-06-10T12:00:00Z")
        XCTAssertEqual(cells[0].hour, 5)
        XCTAssertEqual(cells[0].minute, 30)
        XCTAssertEqual(cells.filter(\.newDay).map(\.date), [cells[0].date, cells[19].date])
        XCTAssertEqual(cells[19].hour, 0)
    }

    func testDaylightSavingJumpSkipsAnHour() {
        // New York springs forward at 07:00 UTC on 2026-03-08: 01:00 EST is followed by 03:00 EDT.
        let cells = hours("America/New_York", day: "2026-03-08T12:00:00Z")
        XCTAssertEqual(cells[6].hour, 1)
        XCTAssertEqual(cells[7].hour, 3)
        XCTAssertEqual(cells.filter(\.newDay).count, 2)
    }

    func testBandsAndOffsets() {
        XCTAssertEqual([3, 7, 12, 18, 23].map(Band.init), [.night, .edge, .work, .edge, .night])
        XCTAssertEqual(TimeGrid.utcOffset(TimeZone(identifier: "Asia/Kolkata")!, at: date), "UTC+5:30")
        XCTAssertEqual(TimeGrid.utcOffset(TimeZone(identifier: "America/Los_Angeles")!, at: date), "UTC\u{2212}7")
        XCTAssertEqual(TimeGrid.utcOffset(utc, at: date), "UTC")
        XCTAssertEqual(HourCell(date: date, zone: utc, hour: 14, minute: 0, newDay: false).label(twelveHour: true), "2p")
    }

    func testCitiesRoundTripAndSearch() {
        XCTAssertEqual(City.search("san fran").map(\.zone), ["America/Los_Angeles"])
        XCTAssertEqual(City.defaults.compactMap { City(id: $0.id) }, City.defaults)
        XCTAssertNil(City(id: "Nowhere|Mars/Olympus"))
        XCTAssertEqual(City.all.filter { ["Calcutta", "Kolkata"].contains($0.name) }.map(\.name), ["Kolkata"])
        XCTAssertEqual(City.all.count, Set(City.all.map(\.name)).count)
    }
}
