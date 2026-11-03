import Foundation
import Testing
@testable import Meridian

struct CityTimeTests {
    /// "NOV 2", in the cell's own zone.
    private func tag(_ cell: HourCell) -> String {
        cell.date.formatted(Date.FormatStyle(timeZone: cell.zone).month(.abbreviated).day()).uppercased()
    }

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
        #expect(london.dayLabel == "Yesterday · \u{2212}8")
    }

    @Test func testTwentyFourHourClockHasNoPeriod() {
        let london = time("Europe/London", locale: uk)
        #expect(london.time == "17:30")
        #expect(london.period == nil)
    }

    @Test func testHalfHourOffsetAndSameDay() {
        #expect(time("Asia/Kolkata", locale: uk).dayLabel == "Yesterday · \u{2212}2:30")
        #expect(time("Asia/Tokyo", locale: uk).dayLabel == "Today · +1")
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

    // MARK: - Grid mapping

    private func zone(_ id: String) -> TimeZone { TimeZone(identifier: id)! }
    private func instant(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
    private func columns(home: String, day: String, days: Int = 0) -> [Date] {
        TimeGrid.dayColumns(home: zone(home), date: instant(day), days: days)
    }
    private func cells(_ zoneID: String, _ columns: [Date]) -> [HourCell] {
        TimeGrid.cells(in: zone(zoneID), columns: columns)
    }
    private func clock(_ cells: [HourCell], _ i: Int) -> (Int, Int) { (cells[i].hour, cells[i].minute) }
    private func newDays(_ cells: [HourCell]) -> [Int] { cells.indices.filter { cells[$0].newDay } }

    @Test func testWholeHourHomeMapsOtherZonesWithTheirOddMinutes() {
        // Singapore 00:00 on 2026-06-10 is 2026-06-09T16:00Z.
        let cols = columns(home: "Asia/Singapore", day: "2026-06-10T04:00:00Z")
        #expect(cols.count == 24)
        #expect(cols[0] == instant("2026-06-09T16:00:00Z"))
        #expect(clock(cells("Asia/Singapore", cols), 0) == (0, 0))
        #expect(clock(cells("Asia/Colombo", cols), 0) == (21, 30))        // +5:30 → 21:30 Jun 9
        #expect(clock(cells("Asia/Kathmandu", cols), 0) == (21, 45))      // +5:45 → 21:45 Jun 9
        #expect(clock(cells("Pacific/Chatham", cols), 0) == (4, 45))      // +12:45 (standard in June) → 04:45 Jun 10
        #expect(clock(cells("America/St_Johns", cols), 0) == (13, 30))    // −2:30 (NDT in June) → 13:30 Jun 9
        #expect(clock(cells("America/New_York", cols), 0) == (12, 0))     // −4 (EDT) → 12:00 Jun 9
        #expect(clock(cells("Europe/London", cols), 0) == (17, 0))        // +1 (BST) → 17:00 Jun 9
        #expect(cells("Asia/Colombo", cols).allSatisfy { $0.minute == 30 })
        #expect(cells("Asia/Kathmandu", cols).allSatisfy { $0.minute == 45 })
    }

    @Test func testWholeHourHomeMapsNewfoundlandStandardTime() {
        // Singapore 00:00 on 2026-01-14 is 2026-01-13T16:00Z; St John's is on NST −3:30 → 12:30 Jan 13.
        let cols = columns(home: "Asia/Singapore", day: "2026-01-14T04:00:00Z")
        #expect(clock(cells("America/St_Johns", cols), 0) == (12, 30))
        #expect(clock(cells("Pacific/Chatham", cols), 0) == (5, 45))      // +13:45 (CHADT in January) → 05:45 Jan 14
    }

    @Test func testHalfHourHomeMapsWholeHourZonesToHalfPast() {
        // Colombo 00:00 on 2026-11-05 is 2026-11-04T18:30Z.
        let cols = columns(home: "Asia/Colombo", day: "2026-11-05T06:00:00Z")
        #expect(cols[0] == instant("2026-11-04T18:30:00Z"))
        #expect(clock(cells("Asia/Colombo", cols), 0) == (0, 0))
        #expect(clock(cells("Asia/Kolkata", cols), 0) == (0, 0))          // same +5:30 offset
        #expect(clock(cells("Asia/Kathmandu", cols), 0) == (0, 15))       // +5:45
        #expect(clock(cells("Asia/Singapore", cols), 0) == (2, 30))       // +8 → 02:30 Nov 5
        #expect(clock(cells("Asia/Tokyo", cols), 0) == (3, 30))           // +9 → 03:30 Nov 5
        #expect(clock(cells("UTC", cols), 0) == (18, 30))                 // 18:30 Nov 4
        #expect(clock(cells("America/New_York", cols), 0) == (13, 30))    // −5 (EST) → 13:30 Nov 4
        #expect(cells("UTC", cols).allSatisfy { $0.minute == 30 })
        #expect(newDays(cells("Asia/Kolkata", cols)) == [0])
        #expect(newDays(cells("UTC", cols)) == [0, 6])                    // UTC midnight is 05:30 Colombo
    }

    @Test func testNewYorkHomeSpringForwardSkipsTwoAM() {
        // 2026-03-08: 00:00 EST is 05:00Z; 02:00 EST never happens, 07:00Z is 03:00 EDT.
        let cols = columns(home: "America/New_York", day: "2026-03-08T12:00:00Z")
        #expect(cols.count == 23)
        #expect(cols.first == instant("2026-03-08T05:00:00Z"))
        #expect(cols.last == instant("2026-03-09T03:00:00Z"))
        #expect(cells("America/New_York", cols).map(\.hour) == [0, 1] + Array(3...23))
        #expect(cells("Europe/London", cols).map(\.hour) == Array(5...23) + [0, 1, 2, 3])   // GMT, no DST until Mar 29
        #expect(cells("Asia/Tokyo", cols).map(\.hour) == Array(14...23) + Array(0...12))
    }

    @Test func testNewYorkHomeFallBackRepeatsOneAM() {
        // 2026-11-01: 00:00 EDT is 04:00Z; 01:00 EDT (05:00Z) is followed by 01:00 EST (06:00Z).
        let cols = columns(home: "America/New_York", day: "2026-11-01T12:00:00Z")
        #expect(cols.count == 25)
        #expect(cols.first == instant("2026-11-01T04:00:00Z"))
        #expect(cols.last == instant("2026-11-02T04:00:00Z"))
        #expect(cells("America/New_York", cols).map(\.hour) == [0, 1, 1] + Array(2...23))
        #expect(cells("Europe/London", cols).map(\.hour) == Array(4...23) + Array(0...4))    // GMT since Oct 25
        #expect(newDays(cells("Europe/London", cols)) == [0, 20])
    }

    @Test func testLondonHomeDaylightSavingDays() {
        // 2026-03-29: 00:00 GMT is 00:00Z; 01:00Z is already 02:00 BST.
        let spring = columns(home: "Europe/London", day: "2026-03-29T12:00:00Z")
        #expect(spring.count == 23)
        #expect(spring.first == instant("2026-03-29T00:00:00Z"))
        #expect(spring.last == instant("2026-03-29T22:00:00Z"))
        #expect(cells("Europe/London", spring).map(\.hour) == [0] + Array(2...23))
        #expect(cells("UTC", spring).map(\.hour) == Array(0...22))
        // 2026-10-25: 00:00 BST is 23:00Z Oct 24; 01:00 BST (00:00Z) is followed by 01:00 GMT (01:00Z).
        let fall = columns(home: "Europe/London", day: "2026-10-25T12:00:00Z")
        #expect(fall.count == 25)
        #expect(fall.first == instant("2026-10-24T23:00:00Z"))
        #expect(cells("Europe/London", fall).map(\.hour) == [0, 1, 1] + Array(2...23))
        #expect(cells("America/New_York", fall).map(\.hour) == Array(19...23) + Array(0...19))   // still EDT −4
    }

    @Test func testSydneyHomeDaylightSavingDays() {
        // 2026-04-05: 00:00 AEDT (+11) is 13:00Z Apr 4; 03:00 AEDT (16:00Z) becomes 02:00 AEST.
        let fall = columns(home: "Australia/Sydney", day: "2026-04-05T06:00:00Z")
        #expect(fall.count == 25)
        #expect(fall.first == instant("2026-04-04T13:00:00Z"))
        #expect(cells("Australia/Sydney", fall).map(\.hour) == [0, 1, 2, 2] + Array(3...23))
        #expect(cells("Asia/Singapore", fall).map(\.hour) == Array(21...23) + Array(0...21))
        // 2026-10-04: 00:00 AEST (+10) is 14:00Z Oct 3; 02:00 AEST never happens, 16:00Z is 03:00 AEDT.
        let spring = columns(home: "Australia/Sydney", day: "2026-10-04T06:00:00Z")
        #expect(spring.count == 23)
        #expect(spring.first == instant("2026-10-03T14:00:00Z"))
        #expect(cells("Australia/Sydney", spring).map(\.hour) == [0, 1] + Array(3...23))
        #expect(cells("Asia/Singapore", spring).map(\.hour) == Array(22...23) + Array(0...20))
    }

    @Test func testChathamHomeDaylightSavingDays() {
        // 2026-09-27: 00:00 CHAST (+12:45) is 11:15Z Sep 26; 02:45 CHAST (14:00Z) becomes 03:45 CHADT, so 14:15Z is 04:00.
        let spring = columns(home: "Pacific/Chatham", day: "2026-09-27T02:00:00Z")
        #expect(spring.count == 23)
        #expect(spring.first == instant("2026-09-26T11:15:00Z"))
        #expect(cells("Pacific/Chatham", spring).map(\.hour) == [0, 1, 2] + Array(4...23))
        #expect(cells("Pacific/Chatham", spring).allSatisfy { $0.minute == 0 })
        #expect(cells("UTC", spring).map(\.minute).allSatisfy { $0 == 15 })
        #expect(cells("UTC", spring).map(\.hour) == Array(11...23) + Array(0...9))
        // 2026-04-05: 00:00 CHADT (+13:45) is 10:15Z Apr 4; 03:45 CHADT (14:00Z) becomes 02:45 CHAST, so 14:15Z is 03:00 again.
        let fall = columns(home: "Pacific/Chatham", day: "2026-04-05T02:00:00Z")
        #expect(fall.count == 25)
        #expect(fall.first == instant("2026-04-04T10:15:00Z"))
        #expect(cells("Pacific/Chatham", fall).map(\.hour) == [0, 1, 2, 3, 3] + Array(4...23))
        #expect(cells("UTC", fall).map(\.hour) == Array(10...23) + Array(0...10))
    }

    @Test func testLordHoweHomeHalfHourDaylightSavingShift() {
        // Lord Howe shifts by 30 minutes: +10:30 standard, +11 daylight.
        // 2026-10-04: 00:00 (+10:30) is 13:30Z Oct 3; 02:00 becomes 02:30, so from 15:30Z the hourly stride lands on x:30.
        // Next midnight (+11) is 13:00Z Oct 4, 23.5h later, so the day has 24 columns.
        let spring = columns(home: "Australia/Lord_Howe", day: "2026-10-04T02:00:00Z")
        #expect(spring.count == 24)
        #expect(spring.first == instant("2026-10-03T13:30:00Z"))
        let springHome = cells("Australia/Lord_Howe", spring)
        #expect(springHome.map(\.hour) == Array(0...23))
        #expect(springHome.map(\.minute) == [0, 0] + Array(repeating: 30, count: 22))
        #expect(cells("Australia/Sydney", spring).map(\.minute).allSatisfy { $0 == 30 })   // AEDT +11 all day
        // 2026-04-05: 00:00 (+11) is 13:00Z Apr 4; 02:00 becomes 01:30, so from 15:00Z columns land on x:30.
        // Next midnight (+10:30) is 13:30Z Apr 5, 24.5h later, so the day has 25 columns.
        let fall = columns(home: "Australia/Lord_Howe", day: "2026-04-05T02:00:00Z")
        #expect(fall.count == 25)
        #expect(fall.first == instant("2026-04-04T13:00:00Z"))
        let fallHome = cells("Australia/Lord_Howe", fall)
        #expect(fallHome.map(\.hour) == [0, 1, 1] + Array(2...23))
        #expect(fallHome.map(\.minute) == [0, 0] + Array(repeating: 30, count: 23))
    }

    @Test func testOtherZoneChangesDaylightSavingMidGridWhileHomeDoesNot() {
        // Home Tokyo on 2026-03-08: 00:00 JST is 15:00Z Mar 7. New York springs forward at 07:00Z, column 16.
        let cols = columns(home: "Asia/Tokyo", day: "2026-03-08T03:00:00Z")
        #expect(cols.count == 24)
        let newYork = cells("America/New_York", cols)
        #expect(clock(newYork, 0) == (10, 0))                             // 10:00 EST Mar 7
        #expect(newYork.map(\.hour) == Array(10...23) + [0, 1, 3, 4, 5, 6, 7, 8, 9, 10])
        #expect(newDays(newYork) == [0, 14])                              // 05:00Z Mar 8 is 00:00 EST
        #expect(tag(newYork[14]) == "MAR 8" && tag(newYork[0]) == "MAR 7")
        #expect(cells("Asia/Tokyo", cols).map(\.hour) == Array(0...23))
    }

    @Test func testNewDayFlagForZonesAheadAndBehindHome() {
        // Singapore 00:00 on 2026-06-10 is 16:00Z Jun 9; column i is 16:00Z + i hours.
        let cols = columns(home: "Asia/Singapore", day: "2026-06-10T04:00:00Z")
        #expect(newDays(cells("Asia/Singapore", cols)) == [0])
        #expect(newDays(cells("Asia/Tokyo", cols)) == [0, 23])            // +9: 00:00 Jun 11 is 15:00Z Jun 10
        #expect(newDays(cells("Europe/London", cols)) == [0, 7])          // +1: 00:00 Jun 10 is 23:00Z Jun 9
        #expect(newDays(cells("America/New_York", cols)) == [0, 12])      // −4: 00:00 Jun 10 is 04:00Z
        #expect(newDays(cells("Pacific/Kiritimati", cols)) == [0, 18])    // +14: 00:00 Jun 11 is 10:00Z Jun 10
        #expect(newDays(cells("Pacific/Pago_Pago", cols)) == [0, 19])     // −11: 00:00 Jun 10 is 11:00Z Jun 10
        let kiritimati = cells("Pacific/Kiritimati", cols)
        #expect(clock(kiritimati, 0) == (6, 0) && tag(kiritimati[0]) == "JUN 10")
        #expect(clock(kiritimati, 18) == (0, 0) && tag(kiritimati[18]) == "JUN 11")
        let pagoPago = cells("Pacific/Pago_Pago", cols)
        #expect(clock(pagoPago, 0) == (5, 0) && tag(pagoPago[0]) == "JUN 9")
        #expect(clock(pagoPago, 19) == (0, 0) && tag(pagoPago[19]) == "JUN 10")
        #expect(pagoPago[0].weekday == "TUE" && kiritimati[18].weekday == "THU")
    }

    @Test func testDaysOffsetShiftsTheWholeGridByAHomeDay() {
        // From 12:00 Singapore on 2026-06-10 (04:00Z): tomorrow starts 16:00Z Jun 10, yesterday 16:00Z Jun 8.
        let tomorrow = columns(home: "Asia/Singapore", day: "2026-06-10T04:00:00Z", days: 1)
        let yesterday = columns(home: "Asia/Singapore", day: "2026-06-10T04:00:00Z", days: -1)
        #expect(tomorrow.first == instant("2026-06-10T16:00:00Z") && tomorrow.count == 24)
        #expect(yesterday.first == instant("2026-06-08T16:00:00Z") && yesterday.count == 24)
        #expect(tag(cells("Asia/Singapore", tomorrow)[0]) == "JUN 11")
        #expect(tag(cells("Asia/Singapore", yesterday)[0]) == "JUN 9")
        #expect(newDays(cells("Pacific/Kiritimati", tomorrow)) == [0, 18])
        #expect(newDays(cells("Pacific/Pago_Pago", yesterday)) == [0, 19])
        #expect(tag(cells("Pacific/Pago_Pago", yesterday)[19]) == "JUN 9")     // 11:00Z Jun 9 is 00:00 Jun 9 in Pago Pago
        // Crossing a home DST change: the day after New York's 2026-03-08 is a normal 24-column day starting 04:00Z.
        let afterSpring = columns(home: "America/New_York", day: "2026-03-08T12:00:00Z", days: 1)
        #expect(afterSpring.count == 24 && afterSpring.first == instant("2026-03-09T04:00:00Z"))
        #expect(columns(home: "America/New_York", day: "2026-03-09T12:00:00Z", days: -1).count == 23)
    }

    @Test func testCitiesRoundTripAndSearch() {
        #expect(City.search("san fran").map(\.zone) == ["America/Los_Angeles"])
        #expect(City.defaults.compactMap { City(id: $0.id) } == City.defaults)
        #expect(City(id: "Nowhere|Mars/Olympus") == nil)
        #expect(City.all.filter { ["Calcutta", "Kolkata"].contains($0.name) }.map(\.name) == ["Kolkata"])
        #expect(City.all.count == Set(City.all.map(\.name)).count)
    }

    @Test func testSummaryHasOneLinePerCityWithTheEndDayWhenItDiffers() {
        let cities = [City(name: "London", zone: "Europe/London"), City(name: "Tokyo", zone: "Asia/Tokyo")]
        let start = instant("2026-11-03T14:00:00Z"), end = instant("2026-11-03T16:00:00Z")
        #expect(TimeGrid.summary(cities, start: start, end: nil, twelveHour: false) == "London: Tue 3 Nov, 14:00\nTokyo: Tue 3 Nov, 23:00")
        #expect(TimeGrid.summary(cities, start: start, end: end, twelveHour: true)
            == "London: Tue, Nov 3, 2:00 PM - 4:00 PM\nTokyo: Tue, Nov 3, 11:00 PM - Wed, Nov 4, 1:00 AM")
    }
}
