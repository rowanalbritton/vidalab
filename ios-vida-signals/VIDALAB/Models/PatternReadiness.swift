import Foundation

/// How close the member is to trustworthy patterns, and what to say about it.
///
/// The old behaviour was to render nothing until a correlation appeared, which
/// meant the most important screen in the app was blank for the first two weeks
/// — exactly when someone is deciding whether this is worth the daily effort.
/// Every state below says where she is, what happens next, and what to do now.
nonisolated struct PatternReadiness: Equatable {
    /// Days with at least one logged signal.
    let loggedDays: Int
    /// Connections Vida is willing to show.
    let visibleCount: Int
    /// Days at which Vida considers a pattern properly established.
    static let target: Int = 14
    /// Minimum overlapping days before any connection is surfaced at all.
    static let floor: Int = 6

    enum Stage: Equatable {
        /// Nothing logged yet.
        case empty
        /// Logging, but not enough days for any connection to be trusted.
        case building
        /// Enough days, but nothing correlated. A real result, not a failure.
        case noneFound
        /// At least one connection worth showing.
        case ready
    }

    var stage: Stage {
        if loggedDays == 0 { return .empty }
        if visibleCount > 0 { return .ready }
        return loggedDays < Self.floor ? .building : .noneFound
    }

    var daysRemaining: Int { max(0, Self.target - loggedDays) }

    /// 0–1 toward the 14-day mark, for the progress meter.
    var progress: Double {
        min(1, Double(loggedDays) / Double(Self.target))
    }

    var title: String {
        switch stage {
        case .empty: "Your map starts with one check-in"
        case .building: "Patterns unlock at \(Self.target) days"
        case .noneFound: "No clear pattern yet"
        case .ready: "Worth noticing"
        }
    }

    /// Always names the current position — a progress state that hides the
    /// number is just a loading spinner with better manners.
    var message: String {
        switch stage {
        case .empty:
            return "Vida finds patterns by comparing your days against each other. It needs a few before it can compare anything. The first check-in takes about thirty seconds."
        case .building:
            return "Keep checking in — Vida needs about \(Self.floor) days before a connection can be trusted, and \(Self.target) before it calls one consistent. You're at \(loggedDays)."
        case .noneFound:
            return "You're at \(loggedDays) days and nothing has moved together strongly enough to report. That's a genuine finding, not a failure — it means no single signal is driving the others right now."
        case .ready:
            return "Built from \(loggedDays) days of your own check-ins."
        }
    }

    /// The one useful next action, so no state is a dead end.
    var actionLabel: String {
        switch stage {
        case .empty, .building: "Check in now"
        case .noneFound: "Add a signal to track"
        case .ready: "See all connections"
        }
    }

    /// Concrete suggestion for the "nothing found" case, which is otherwise the
    /// easiest state to leave someone stranded in.
    var suggestion: String? {
        guard stage == .noneFound else { return nil }
        return "Tracking one more signal often breaks it open — stress and movement are the two that most often explain the others."
    }
}
