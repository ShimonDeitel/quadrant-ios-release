import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store of tasks, exposes the current day's matrix, applies the
/// recurring-task re-seed (Pro), and derives weekly analytics. Stats are always derived from the
/// stored tasks — never stored truth.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    /// The day whose matrix is on screen (start-of-day). Defaults to today.
    @Published var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    /// Bumped on every mutation so SwiftUI views re-pull derived data.
    @Published private(set) var revision = 0

    private let cal = Calendar.current
    private let kLastSeedDay = "quadrant.lastRecurringSeedDay"

    init(container: ModelContainer) {
        self.container = container
        #if DEBUG
        seedIfRequested()
        #endif
        reseedRecurringIfNeeded()
    }

    // MARK: Container (local-only on-device persistence; no iCloud/CloudKit)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([TaskItem.self])
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Fetching

    func allTasks() -> [TaskItem] {
        (try? container.mainContext.fetch(FetchDescriptor<TaskItem>())) ?? []
    }

    /// Tasks belonging to a given calendar day.
    func tasks(on day: Date) -> [TaskItem] {
        let target = cal.startOfDay(for: day)
        return allTasks().filter { cal.isDate($0.date, inSameDayAs: target) }
    }

    /// Today's matrix tasks (the selected day).
    func tasksForSelectedDay() -> [TaskItem] { tasks(on: selectedDay) }

    /// The four-box tally for the selected day.
    func selectedDayTallies() -> [QuadrantTally] {
        MatrixAnalytics.tallies(tasksForSelectedDay())
    }

    // MARK: Mutations

    @discardableResult
    func addTask(title: String, quadrant: Quadrant, recurring: Bool = false) -> TaskItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Recurring is a Pro bonus; never persist a recurring flag for a free user even past the UI.
        let isRecurring = recurring && (store?.isPro == true)
        let ctx = container.mainContext
        let task = TaskItem(title: trimmed, quadrant: quadrant,
                            date: cal.startOfDay(for: selectedDay), recurring: isRecurring)
        ctx.insert(task)
        try? ctx.save()
        bump()
        return task
    }

    func move(_ task: TaskItem, to quadrant: Quadrant) {
        guard task.quadrant != quadrant else { return }
        task.quadrant = quadrant
        try? container.mainContext.save()
        bump()
    }

    func toggleDone(_ task: TaskItem) {
        task.done.toggle()
        try? container.mainContext.save()
        bump()
    }

    func delete(_ task: TaskItem) {
        container.mainContext.delete(task)
        try? container.mainContext.save()
        bump()
    }

    // MARK: Analytics passthrough (selected day + week)

    func weekTrend() -> [DayBalance] {
        MatrixAnalytics.weekTrend(allTasks(), now: selectedDay)
    }

    /// Win/trap totals across the trailing week (for the reflection summary).
    func weekWinTrap() -> (win: Int, trap: Int) {
        let trend = weekTrend()
        return (trend.reduce(0) { $0 + $1.winCount }, trend.reduce(0) { $0 + $1.trapCount })
    }

    func focusScoreForSelectedDay() -> Double {
        MatrixAnalytics.focusScore(tasksForSelectedDay())
    }

    // MARK: Recurring re-seed (Pro)

    /// On the first launch of a new calendar day, copy yesterday's recurring tasks forward as fresh,
    /// not-done tasks for today. Runs once per day (guarded by a stored day stamp). No-op if a
    /// recurring task was already copied for today.
    func reseedRecurringIfNeeded() {
        let today = cal.startOfDay(for: .now)
        let stampedDay = (UserDefaults.standard.object(forKey: kLastSeedDay) as? Date)
            .map { cal.startOfDay(for: $0) }
        if stampedDay == today { return }

        let templates = allTasks().filter { $0.recurring }
        // The newest recurring instance per title is the live template.
        var latestByTitle: [String: TaskItem] = [:]
        for t in templates {
            if let existing = latestByTitle[t.title], existing.createdAt >= t.createdAt { continue }
            latestByTitle[t.title] = t
        }
        let ctx = container.mainContext
        let todayTitles = Set(tasks(on: today).map { $0.title })
        for (title, template) in latestByTitle where !todayTitles.contains(title) {
            ctx.insert(TaskItem(title: title, quadrant: template.quadrant,
                                done: false, date: today, recurring: true))
        }
        try? ctx.save()
        UserDefaults.standard.set(today, forKey: kLastSeedDay)
        bump()
    }

    // MARK: Account deletion

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: TaskItem.self)
        try? ctx.save()
        UserDefaults.standard.removeObject(forKey: kLastSeedDay)
        bump()
    }

    func refresh() { bump() }

    private func bump() { revision &+= 1 }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["QUADRANT_SEED"] == "1" else { return }
        let ctx = container.mainContext
        guard ((try? ctx.fetch(FetchDescriptor<TaskItem>()))?.isEmpty ?? true) else { return }
        let today = cal.startOfDay(for: .now)
        let sample: [(String, Quadrant, Int)] = [
            ("Finish client proposal", .doNow, 0),
            ("Reply to urgent email", .doNow, 0),
            ("Plan next sprint", .schedule, 0),
            ("Book dentist", .schedule, 0),
            ("Forward meeting invite", .delegate, 0),
            ("Approve small expense", .delegate, 0),
            ("Scroll social feed", .eliminate, 0),
            ("Old newsletter cleanup", .schedule, 1),
            ("Yesterday busywork", .delegate, 1),
            ("Two days ago plan", .schedule, 2)
        ]
        for (title, q, offset) in sample {
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            ctx.insert(TaskItem(title: title, quadrant: q, date: day))
        }
        try? ctx.save()
    }
    #endif
}
