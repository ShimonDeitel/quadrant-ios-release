import SwiftUI

/// The four boxes of the Eisenhower matrix, keyed by (urgent, important).
/// Stored on each `TaskItem` as a stable raw string so the schema mirrors to CloudKit cleanly.
enum Quadrant: String, CaseIterable, Identifiable, Codable {
    case doNow          // urgent + important     → the "do now" box
    case schedule       // not urgent + important → the win box (plan it)
    case delegate       // urgent + not important → the trap box (busywork)
    case eliminate      // not urgent + not important → drop it

    var id: String { rawValue }

    /// Whether the quadrant is urgent (left-to-right axis).
    var isUrgent: Bool { self == .doNow || self == .delegate }
    /// Whether the quadrant is important (top-to-bottom axis).
    var isImportant: Bool { self == .doNow || self == .schedule }

    /// Short title shown in the box header.
    var title: String {
        switch self {
        case .doNow: return "Do Now"
        case .schedule: return "Schedule"
        case .delegate: return "Delegate"
        case .eliminate: return "Eliminate"
        }
    }

    /// The urgent/important descriptor under the title.
    var axisLabel: String {
        switch self {
        case .doNow: return "Urgent · Important"
        case .schedule: return "Not urgent · Important"
        case .delegate: return "Urgent · Not important"
        case .eliminate: return "Not urgent · Not important"
        }
    }

    /// One-line coaching note.
    var advice: String {
        switch self {
        case .doNow: return "Do these first."
        case .schedule: return "Plan a time for these."
        case .delegate: return "Hand off or batch these."
        case .eliminate: return "Drop what you can."
        }
    }

    var symbol: String {
        switch self {
        case .doNow: return "flame.fill"
        case .schedule: return "calendar"
        case .delegate: return "arrowshape.turn.up.right.fill"
        case .eliminate: return "trash"
        }
    }

    /// Accent for the box. Only "Do Now" uses the Apple-blue accent; the rest stay neutral grey
    /// so the matrix reads at a glance (minimalist: one accent colour).
    var tint: Color {
        switch self {
        case .doNow: return .appAccent
        default: return Color(uiColor: .secondaryLabel)
        }
    }

    /// The "win" quadrant — important work you got ahead of (schedule). Landing here is good.
    var isWin: Bool { self == .schedule }
    /// The "trap" quadrant — urgent-but-unimportant busywork (delegate). Landing here is the trap.
    var isTrap: Bool { self == .delegate }

    /// Reading order for the 2x2 grid: top row important, bottom row not-important.
    static let gridOrder: [Quadrant] = [.doNow, .schedule, .delegate, .eliminate]
}
