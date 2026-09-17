import Foundation

/// Finds relationships between logged categories. Deliberately conservative:
/// Vida surfaces "a pattern worth noticing", never a diagnosis.
nonisolated enum PatternEngine {

    /// Pearson correlation between two categories across days where both were logged.
    static func link(_ a: SignalCategory, _ b: SignalCategory, in logs: [DayLog]) -> PatternLink? {
        var xs: [Double] = []
        var ys: [Double] = []
        for log in logs {
            guard let ra = log.reading(for: a), let rb = log.reading(for: b) else { continue }
            xs.append(normalize(ra.value, for: a))
            ys.append(normalize(rb.value, for: b))
        }
        guard xs.count >= 4 else { return nil }
        guard let r = pearson(xs, ys) else { return nil }
        return PatternLink(a: a, b: b, strength: r, sampleSize: xs.count)
    }

    static func allLinks(in logs: [DayLog]) -> [PatternLink] {
        let cats = SignalCategory.checkInSet
        var results: [PatternLink] = []
        for i in 0..<cats.count {
            for j in (i + 1)..<cats.count {
                if let link = link(cats[i], cats[j], in: logs) {
                    results.append(link)
                }
            }
        }
        return results.sorted { $0.magnitude > $1.magnitude }
    }

    static func meaningfulLinks(in logs: [DayLog]) -> [PatternLink] {
        allLinks(in: logs).filter(\.isMeaningful)
    }

    /// Scales sleep hours onto the same 0–10 footing as everything else.
    static func normalize(_ value: Double, for category: SignalCategory) -> Double {
        category == .sleep ? min(10, value * 10.0 / 10.0) : value
    }

    private static func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n
        let my = ys.reduce(0, +) / n
        var num = 0.0, dx = 0.0, dy = 0.0
        for i in xs.indices {
            let a = xs[i] - mx
            let b = ys[i] - my
            num += a * b
            dx += a * a
            dy += b * b
        }
        let denom = (dx * dy).squareRoot()
        guard denom > 0.0001 else { return nil }
        return num / denom
    }

    /// Plain-language sentence for a link, framed as an observation.
    static func sentence(for link: PatternLink, logs: [DayLog]) -> String {
        let driver = link.a
        let outcome = link.b
        let direction = link.strength > 0 ? "higher" : "lower"
        let driverWord = driver == .sleep ? "more sleep" : "higher \(driver.title.lowercased())"
        return "On days with \(driverWord), you've tended to report \(direction) \(outcome.title.lowercased()) — across \(link.sampleSize) days where you logged both."
    }

    /// Day-by-day view of an experiment window, used for the logging strip.
    /// Stops at today so future days aren't shown as "missed".
    static func days(for experiment: Experiment, logs: [DayLog], today: Date) -> [ExperimentDay] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: experiment.startDate)
        var result: [ExperimentDay] = []
        for offset in 0..<experiment.durationDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if date > today { break }
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: date) }
            result.append(
                ExperimentDay(
                    date: date,
                    driver: log?.reading(for: experiment.driver)?.value,
                    outcome: log?.reading(for: experiment.outcome)?.value
                )
            )
        }
        return result
    }

    /// Splits days by a threshold on `driver` and reports how often `outcome` was elevated.
    static func result(for experiment: Experiment, logs: [DayLog]) -> ExperimentResult {
        var highHits = 0, highDays = 0, lowHits = 0, lowDays = 0
        let window = logs.filter { $0.date >= experiment.startDate && $0.date <= experiment.endDate }
        for log in window {
            guard let d = log.reading(for: experiment.driver),
                  let o = log.reading(for: experiment.outcome) else { continue }
            let elevated = experiment.outcome.higherIsBetter ? o.value >= 6 : o.value >= 4
            if d.value >= experiment.threshold {
                highDays += 1
                if elevated { highHits += 1 }
            } else {
                lowDays += 1
                if elevated { lowHits += 1 }
            }
        }
        return ExperimentResult(
            highArmRate: highDays > 0 ? Double(highHits) / Double(highDays) : 0,
            lowArmRate: lowDays > 0 ? Double(lowHits) / Double(lowDays) : 0,
            highArmDays: highDays,
            lowArmDays: lowDays,
            outcome: experiment.outcome
        )
    }
}
