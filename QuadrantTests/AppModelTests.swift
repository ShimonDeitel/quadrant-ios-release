import XCTest
import SwiftData
@testable import Quadrant

/// Integration tests over the live `AppModel` + an in-memory SwiftData store: add / move / toggle,
/// the daily matrix tally, the recurring re-seed (with Pro gating), and free-user gating.
@MainActor
final class AppModelTests: XCTestCase {

    private func memoryModel() -> ModelContainer {
        try! ModelContainer(for: TaskItem.self,
                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func clearSeedStamp() {
        UserDefaults.standard.removeObject(forKey: "quadrant.lastRecurringSeedDay")
    }

    func testAddMoveToggleDelete() {
        clearSeedStamp()
        let model = AppModel(container: memoryModel())
        XCTAssertTrue(model.tasksForSelectedDay().isEmpty)

        let t = model.addTask(title: "  Ship build  ", quadrant: .doNow)
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.title, "Ship build", "title should be trimmed")
        XCTAssertEqual(model.tasksForSelectedDay().count, 1)

        // Empty / whitespace titles are rejected.
        XCTAssertNil(model.addTask(title: "   ", quadrant: .doNow))
        XCTAssertEqual(model.tasksForSelectedDay().count, 1)

        // Move shifts the quadrant; tallies follow.
        model.move(t!, to: .schedule)
        XCTAssertEqual(t!.quadrant, .schedule)
        let tallies = model.selectedDayTallies()
        XCTAssertEqual(tallies.first { $0.quadrant == .doNow }!.total, 0)
        XCTAssertEqual(tallies.first { $0.quadrant == .schedule }!.total, 1)

        // Toggle done.
        XCTAssertFalse(t!.done)
        model.toggleDone(t!)
        XCTAssertTrue(t!.done)

        // Delete.
        model.delete(t!)
        XCTAssertTrue(model.tasksForSelectedDay().isEmpty)
    }

    func testRecurringNotPersistedWithoutPro() {
        clearSeedStamp()
        let model = AppModel(container: memoryModel())
        // No store attached → not Pro → recurring flag must be stripped.
        let t = model.addTask(title: "Daily standup", quadrant: .doNow, recurring: true)
        XCTAssertNotNil(t)
        XCTAssertFalse(t!.recurring, "free users must never persist a recurring task")
    }

    func testRecurringReseedCopiesYesterdaysRecurringTaskForwardOnce() {
        clearSeedStamp()
        let store = Store()
        store.setProForTesting(true)
        let model = AppModel(container: memoryModel())
        model.store = store

        // Author a recurring task dated yesterday (selectedDay is today).
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: .now))!
        let ctx = model.container.mainContext
        ctx.insert(TaskItem(title: "Daily review", quadrant: .schedule,
                            done: true, date: yesterday, recurring: true))
        try? ctx.save()

        // Force a re-seed for "today".
        clearSeedStamp()
        model.reseedRecurringIfNeeded()

        let todays = model.tasks(on: cal.startOfDay(for: .now))
        XCTAssertEqual(todays.count, 1, "recurring task should be copied forward once")
        XCTAssertEqual(todays.first?.title, "Daily review")
        XCTAssertFalse(todays.first?.done ?? true, "the copy starts not-done")
        XCTAssertEqual(todays.first?.quadrant, .schedule)

        // Running again the same day is a no-op (guarded by the day stamp + de-dupe).
        model.reseedRecurringIfNeeded()
        XCTAssertEqual(model.tasks(on: cal.startOfDay(for: .now)).count, 1)
    }

    func testDeleteAllDataClearsTasks() {
        clearSeedStamp()
        let model = AppModel(container: memoryModel())
        model.addTask(title: "a", quadrant: .doNow)
        model.addTask(title: "b", quadrant: .schedule)
        XCTAssertEqual(model.allTasks().count, 2)
        model.deleteAllData()
        XCTAssertTrue(model.allTasks().isEmpty)
    }
}
