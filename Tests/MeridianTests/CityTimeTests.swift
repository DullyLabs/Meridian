import Foundation
import Testing
@testable import Meridian

struct CityTimeTests {
    private let singapore = TimeZone(identifier: "Asia/Singapore")!
    private let us = Locale(identifier: "en_US")
    private let uk = Locale(identifier: "en_GB")
    // 2026-10-29 01:30 in Singapore
    private let date = ISO8601DateFormatter().date(from: "2026-10-28T17:30:00Z")!

    private func time(_ zone: String, locale: Locale) -> CityTime {
        CityTime(city: City(name: City.cityName(zone), zone: zone), date: date, localZone: singapore, locale: locale)
    }

    @Test func testTwelveHourClockSplitsOffThePeriod() {
        let london = time("Europe/London", locale: us)
        #expect(london.time == "5:30")
        #expect(london.period == "PM")
        #expect(london.dayLabel == "Yesterday · \u{2212}8h")
    }

    @Test func testTwentyFourHourClockHasNoPeriod() {
        let london = time("Europe/London", locale: uk)
        #expect(london.time == "17:30")
        #expect(london.period == nil)
    }

    @Test func testHalfHourOffsetAndSameDay() {
        #expect(time("Asia/Kolkata", locale: uk).dayLabel == "Yesterday · \u{2212}2h30")
        #expect(time("Asia/Tokyo", locale: uk).dayLabel == "Today · +1h")
        #expect(time("Asia/Singapore", locale: uk).dayLabel == "Today")
    }

    private let utc = TimeZone(identifier: "UTC")!
    private func hours(_ zone: String, day: String, home: TimeZone? = nil) -> [HourCell] {
        let home = home ?? utc
        let columns = TimeGrid.dayColumns(home: home, date: ISO8601DateFormatter().date(from: day)!)
        return TimeGrid.cells(in: TimeZone(identifier: zone)!, columns: columns)
    }

    @Test func testGridHasTwentyFourColumnsFromHomeMidnight() {
        let cells = hours("Asia/Tokyo", day: "2026-06-10T15:00:00Z")
        #expect(cells.count == 24)
        #expect(cells[0].hour == 9)
        #expect(cells[0].date == ISO8601DateFormatter().date(from: "2026-06-10T00:00:00Z"))
    }

    @Test func testHalfHourZoneKeepsMinutesAndDayBoundary() {
        let cells = hours("Asia/Kolkata", day: "2026-06-10T12:00:00Z")
        #expect(cells[0].hour == 5)
        #expect(cells[0].minute == 30)
        #expect(cells.filter(\.newDay).map(\.date) == [cells[0].date, cells[19].date])
        #expect(cells[19].hour == 0)
    }

    @Test func testDaylightSavingJumpSkipsAnHour() {
        // New York springs forward at 07:00 UTC on 2026-03-08: 01:00 EST is followed by 03:00 EDT.
        let cells = hours("America/New_York", day: "2026-03-08T12:00:00Z")
        #expect(cells[6].hour == 1)
        #expect(cells[7].hour == 3)
        #expect(cells.filter(\.newDay).count == 2)
    }

    @Test func testGridRunsMidnightToMidnightInAHalfHourHomeZone() {
        let colombo = TimeZone(identifier: "Asia/Colombo")!
        let home = hours("Asia/Colombo", day: "2026-11-05T20:00:00Z", home: colombo)
        #expect(home.count == 24)
        #expect(home.allSatisfy { $0.minute == 0 })
        #expect(home[0].hour == 0 && home[23].hour == 23)
        #expect(hours("America/New_York", day: "2026-11-05T20:00:00Z", home: colombo)[0].minute == 30)
    }

    @Test func testDaylightSavingHomeDayHasTwentyThreeOrTwentyFiveColumns() {
        let newYork = TimeZone(identifier: "America/New_York")!
        #expect(hours("America/New_York", day: "2026-03-08T12:00:00Z", home: newYork).count == 23)
        #expect(hours("America/New_York", day: "2026-11-01T12:00:00Z", home: newYork).count == 25)
    }

    @Test func testDefaultsIncludeUTC() {
        #expect(City.defaults.map(\.displayName).dropFirst() == ["London", "New York", "Tokyo", "UTC"])
    }

    @Test func testBandsAndOffsets() {
        #expect([3, 7, 12, 18, 23].map(Band.init) == [.night, .edge, .work, .edge, .night])
        #expect(TimeGrid.utcOffset(TimeZone(identifier: "Asia/Kolkata")!, at: date) == "UTC+5:30")
        #expect(TimeGrid.utcOffset(TimeZone(identifier: "America/Los_Angeles")!, at: date) == "UTC\u{2212}7")
        #expect(TimeGrid.utcOffset(utc, at: date) == "UTC")
        #expect(HourCell(date: date, zone: utc, hour: 14, minute: 0, newDay: false).label(twelveHour: true) == "2p")
    }

    @Test func testCitiesRoundTripAndSearch() {
        #expect(City.search("san fran").map(\.zone) == ["America/Los_Angeles"])
        #expect(City.defaults.compactMap { City(id: $0.id) } == City.defaults)
        #expect(City(id: "Nowhere|Mars/Olympus") == nil)
        #expect(City.all.filter { ["Calcutta", "Kolkata"].contains($0.name) }.map(\.name) == ["Kolkata"])
        #expect(City.all.count == Set(City.all.map(\.name)).count)
    }
}
