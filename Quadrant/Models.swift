import Foundation
import SwiftData

/// One task on the Eisenhower matrix. All properties have defaults and there are no unique
/// constraints, so the schema is CloudKit-mirroring compatible (SwiftData + CloudKit).
@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    /// Raw value of `Quadrant`. Stored as a string for clean CloudKit mirroring.
    var quadrantRaw: String = Quadrant.doNow.rawValue
    var done: Bool = false
    /// The calendar day this task belongs to (start-of-day). Drives the daily matrix + weekly trend.
    var date: Date = Date.now
    var createdAt: Date = Date.now
    /// PRO: when set, the task is a recurring template that re-seeds onto each new day.
    var recurring: Bool = false

    init(id: UUID = UUID(),
         title: String = "",
         quadrant: Quadrant = .doNow,
         done: Bool = false,
         date: Date = .now,
         createdAt: Date = .now,
         recurring: Bool = false) {
        self.id = id
        self.title = title
        self.quadrantRaw = quadrant.rawValue
        self.done = done
        self.date = date
        self.createdAt = createdAt
        self.recurring = recurring
    }

    /// Typed accessor over the stored raw string (falls back to `.doNow` on any bad data).
    var quadrant: Quadrant {
        get { Quadrant(rawValue: quadrantRaw) ?? .doNow }
        set { quadrantRaw = newValue.rawValue }
    }
}
