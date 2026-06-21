import Foundation

/// A read-only snapshot of one quadrant's tally for a period — pure value type for the UI + tests.
struct QuadrantTally: Identifiable {
    let quadrant: Quadrant
    let total: Int
    let done: Int
    var id: String { quadrant.rawValue }
    var open: Int { max(0, total - done) }
    var completionRate: Double { total == 0 ? 0 : Double(done) / Double(total) }
}

/// One day's win/trap counts for the weekly trend chart.
struct DayBalance: Identifiable {
    let date: Date
    let winCount: Int   // tasks in the "schedule" (win) quadrant
    let trapCount: Int  // tasks in the "delegate" (trap) quadrant
    var id: Date { date }
    var total: Int { winCount + trapCount }
}

/// Pure analytics over `[TaskItem]`. Every function is deterministic and free of SwiftData /
/// UIKit so it is fully unit-testable. The `AppModel` calls these and the views render the result.
enum MatrixAnalytics {

    /// Group tasks by quadrant, preserving the canonical four-box order (always returns 4 entries).
    static func tallies(_ tasks: [TaskItem]) -> [QuadrantTally] {
        Quadrant.gridOrder.map { q in
            let inBox = tasks.filter { $0.quadrant == q }
            return QuadrantTally(quadrant: q,
                                 total: inBox.count,
                                 done: inBox.filter { $0.done }.count)
        }
    }

    /// Tasks in a single quadrant, undone first then by creation time (stable list ordering).
    static func tasks(_ tasks: [TaskItem], in quadrant: Quadrant) -> [TaskItem] {
        tasks.filter { $0.quadrant == quadrant }
            .sorted { a, b in
                if a.done != b.done { return !a.done }       // open tasks first
                return a.createdAt < b.createdAt
            }
    }

    /// The win/trap balance for each of the last `days` calendar days, oldest → newest.
    static func weekTrend(_ tasks: [TaskItem], days: Int = 7,
                          calendar: Calendar = .current, now: Date = .now) -> [DayBalance] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let onDay = tasks.filter { calendar.isDate($0.date, inSameDayAs: day) }
            return DayBalance(date: day,
                              winCount: onDay.filter { $0.quadrant.isWin }.count,
                              trapCount: onDay.filter { $0.quadrant.isTrap }.count)
        }
    }

    /// Sum of tasks that landed in the win quadrant over a set of tasks.
    static func winCount(_ tasks: [TaskItem]) -> Int { tasks.filter { $0.quadrant.isWin }.count }
    /// Sum of tasks that landed in the trap quadrant over a set of tasks.
    static func trapCount(_ tasks: [TaskItem]) -> Int { tasks.filter { $0.quadrant.isTrap }.count }

    /// A single 0...1 "focus score": share of all tasks that sit in the two important quadrants
    /// (Do Now + Schedule). Higher means more of your effort is on important work.
    static func focusScore(_ tasks: [TaskItem]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        let important = tasks.filter { $0.quadrant.isImportant }.count
        return Double(important) / Double(tasks.count)
    }
}
