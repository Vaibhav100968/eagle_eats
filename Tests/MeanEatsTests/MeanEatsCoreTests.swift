import XCTest
@testable import eaglesEats2

final class MealPeriodTests: XCTestCase {

    private func date(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 10
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    func testBreakfastWindow() {
        XCTAssertEqual(MealPeriod.current(for: date(hour: 7)), .breakfast)
        XCTAssertEqual(MealPeriod.current(for: date(hour: 9, minute: 30)), .breakfast)
    }

    func testLunchWindow() {
        XCTAssertEqual(MealPeriod.current(for: date(hour: 10)), .lunch)
        XCTAssertEqual(MealPeriod.current(for: date(hour: 13, minute: 59)), .lunch)
    }

    func testDinnerWindow() {
        XCTAssertEqual(MealPeriod.current(for: date(hour: 14)), .dinner)
        XCTAssertEqual(MealPeriod.current(for: date(hour: 20, minute: 45)), .dinner)
    }

    func testLateNightWindow() {
        XCTAssertEqual(MealPeriod.current(for: date(hour: 21)), .lateNight)
        XCTAssertEqual(MealPeriod.current(for: date(hour: 23, minute: 30)), .lateNight)
    }

    func testClosedEarlyMorning() {
        XCTAssertEqual(MealPeriod.current(for: date(hour: 2)), .closed)
        XCTAssertEqual(MealPeriod.current(for: date(hour: 6, minute: 59)), .closed)
    }
}

final class BalanceScraperTests: XCTestCase {

    func testParsesSwipesAndFlex() {
        let portal = """
        Welcome, Jane Doe
        Mean Green Meal Plan
        Meal swipes left  14
        Flex MP
        Current Balance
        $45.25
        """
        let info = BalanceScraper.parse(portal)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.diningSwipes, 14)
        XCTAssertEqual(info?.flexBalance, 45.25, accuracy: 0.001)
        XCTAssertEqual(info?.accountHolder, "Jane Doe")
    }

    func testParsesUnlimitedSwipes() {
        let portal = """
        Meal swipes left
        Unlimited
        Current Balance $12.00
        """
        let info = BalanceScraper.parse(portal)
        XCTAssertEqual(info?.diningSwipes, 9999)
        XCTAssertEqual(info?.swipesDisplay, "Unlimited")
    }

    func testEmptyTextReturnsNil() {
        XCTAssertNil(BalanceScraper.parse(""))
    }

    func testMatchFirstAmount() {
        XCTAssertEqual(BalanceScraper.matchFirstAmount(in: "$12.50 leftover"), 12.50, accuracy: 0.001)
        XCTAssertEqual(BalanceScraper.matchFirstAmount(in: "balance 8,25"), 8.25, accuracy: 0.001)
    }
}

final class MealPlanInfoTests: XCTestCase {

    func testFlexDisplay() {
        var info = MealPlanInfo(lastUpdated: Date())
        XCTAssertEqual(info.flexDisplay, "—")
        info.flexBalance = 10.5
        XCTAssertEqual(info.flexDisplay, "$10.50")
    }

    func testSwipesDisplay() {
        var info = MealPlanInfo(lastUpdated: Date())
        XCTAssertEqual(info.swipesDisplay, "—")
        info.diningSwipes = 7
        XCTAssertEqual(info.swipesDisplay, "7")
        info.diningSwipes = 9999
        XCTAssertEqual(info.swipesDisplay, "Unlimited")
    }

    func testHasAnyData() {
        var info = MealPlanInfo(lastUpdated: Date())
        XCTAssertFalse(info.hasAnyData)
        info.flexBalance = 1
        XCTAssertTrue(info.hasAnyData)
    }
}

final class ContentFilterTests: XCTestCase {

    func testAcceptsNormalReview() {
        XCTAssertTrue(ContentFilter.isAcceptable("Great pasta station today"))
    }

    func testRejectsEmpty() {
        XCTAssertFalse(ContentFilter.isAcceptable("   "))
    }

    func testRejectsBlockedTerms() {
        XCTAssertFalse(ContentFilter.isAcceptable("This is spam content"))
        XCTAssertFalse(ContentFilter.isAcceptable("I hate this place"))
    }
}

final class AllergenParsingTests: XCTestCase {

    func testCommonAliases() {
        XCTAssertEqual(Allergen.from(string: "dairy"), .milk)
        XCTAssertEqual(Allergen.from(string: "egg"), .eggs)
        XCTAssertEqual(Allergen.from(string: "soy"), .soybeans)
        XCTAssertEqual(Allergen.from(string: "gluten"), .wheat)
        XCTAssertNil(Allergen.from(string: "unknown-thing"))
    }
}
