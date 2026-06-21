import XCTest
@testable import Quadrant

/// Pure-logic tests for the Eisenhower matrix: quadrant axes, analytics tallies, the weekly
/// win/trap trend, the focus score, and the StoreKit product wiring.
final class QuadrantTests: XCTestCase {

    private let cal = Calendar.current

    private func task(_ title: String, _ q: Quadrant, done: Bool = false,
                      dayOffset: Int = 0) -> TaskItem {
        let day = cal.date(byAdding: .day, value: -dayOffset, to: cal.startOfDay(for: .now))!
        return TaskItem(title: title, quadrant: q, done: done, date: day)
    }

    // MARK: Quadrant axis semantics

    func testQuadrantAxes() {
        XCTAssertTrue(Quadrant.doNow.isUrgent && Quadrant.doNow.isImportant)
        XCTAssertTrue(Quadrant.schedule.isImportant && !Quadrant.schedule.isUrgent)
        XCTAssertTrue(Quadrant.delegate.isUrgent && !Quadrant.delegate.isImportant)
        XCTAssertFalse(Quadrant.eliminate.isUrgent || Quadrant.eliminate.isImportant)
        // The win is Schedule; the trap is Delegate.
        XCTAssertTrue(Quadrant.schedule.isWin)
        XCTAssertTrue(Quadrant.delegate.isTrap)
        XCTAssertFalse(Quadrant.doNow.isWin)
        XCTAssertEqual(Quadrant.gridOrder.count, 4)
        // Bad raw data falls back to .doNow, never crashes.
        let t = TaskItem(title: "x")
        t.quadrantRaw = "garbage"
        XCTAssertEqual(t.quadrant, .doNow)
    }

    // MARK: Tallies (always 4 boxes, correct counts)

    func testTalliesAlwaysReturnFourBoxesWithCounts() {
        let tasks = [
            task("a", .doNow, done: true),
            task("b", .doNow),
            task("c", .schedule),
            task("d", .delegate, done: true)
        ]
        let tallies = MatrixAnalytics.tallies(tasks)
        XCTAssertEqual(tallies.count, 4)
        let doNow = tallies.first { $0.quadrant == .doNow }!
        XCTAssertEqual(doNow.total, 2)
        XCTAssertEqual(doNow.done, 1)
        XCTAssertEqual(doNow.open, 1)
        XCTAssertEqual(doNow.completionRate, 0.5, accuracy: 0.0001)
        let elim = tallies.first { $0.quadrant == .eliminate }!
        XCTAssertEqual(elim.total, 0)
        XCTAssertEqual(elim.completionRate, 0)
    }

    // MARK: Quadrant task ordering — open before done, then by creation time

    func testTasksInQuadrantPutOpenFirst() {
        let done = task("done", .doNow, done: true)
        let open = task("open", .doNow)
        let result = MatrixAnalytics.tasks([done, open], in: .doNow)
        XCTAssertEqual(result.map { $0.title }, ["open", "done"])
        // Other quadrants are filtered out.
        XCTAssertTrue(MatrixAnalytics.tasks([done, open], in: .schedule).isEmpty)
    }

    // MARK: Weekly win/trap trend

    func testWeekTrendCountsWinsAndTrapsPerDay() {
        let tasks = [
            task("win today", .schedule, dayOffset: 0),
            task("trap today", .delegate, dayOffset: 0),
            task("trap today 2", .delegate, dayOffset: 0),
            task("win yesterday", .schedule, dayOffset: 1),
            task("donow", .doNow, dayOffset: 0) // not a win or trap
        ]
        let trend = MatrixAnalytics.weekTrend(tasks, days: 7)
        XCTAssertEqual(trend.count, 7)
        // Oldest first → last element is today.
        let today = trend.last!
        XCTAssertEqual(today.winCount, 1)
        XCTAssertEqual(today.trapCount, 2)
        let yesterday = trend[trend.count - 2]
        XCTAssertEqual(yesterday.winCount, 1)
        XCTAssertEqual(yesterday.trapCount, 0)
        XCTAssertEqual(MatrixAnalytics.winCount(tasks), 2)
        XCTAssertEqual(MatrixAnalytics.trapCount(tasks), 2)
    }

    // MARK: Focus score = share of important tasks

    func testFocusScore() {
        XCTAssertEqual(MatrixAnalytics.focusScore([]), 0)
        let tasks = [
            task("a", .doNow),      // important
            task("b", .schedule),   // important
            task("c", .delegate),   // not important
            task("d", .eliminate)   // not important
        ]
        XCTAssertEqual(MatrixAnalytics.focusScore(tasks), 0.5, accuracy: 0.0001)
        let allImportant = [task("a", .doNow), task("b", .schedule)]
        XCTAssertEqual(MatrixAnalytics.focusScore(allImportant), 1.0, accuracy: 0.0001)
    }

    // MARK: Store wiring

    @MainActor
    func testStoreProductIDAndPriceFallback() async {
        let store = Store()
        try? await Task.sleep(for: .seconds(0.3))
        XCTAssertEqual(Store.productID, "quadrant_pro_unlock")
        XCTAssertEqual(store.displayPrice, "$0.99")
        XCTAssertFalse(store.isPro, "Pro must start locked")
    }
}
