import Charts
import SwiftUI

/// One day's worth of the two signals this chart compares.
///
/// Both are optional because a day is rarely complete: a morning check-in
/// gives sleep and no evening mood, and the reverse happens just as often.
/// Dropping those days would quietly shorten the window and overstate how
/// consistently someone has been logging.
nonisolated struct SleepMoodPoint: Identifiable, Hashable {
    let date: Date
    let sleepHours: Double?
    let mood: Double?

    var id: Date { date }

    /// Only days with both can speak to the relationship between them.
    var isPaired: Bool { sleepHours != nil && mood != nil }
}

/// Sleep and mood on one timeline, so a night can be read against the day
/// that followed it.
///
/// Drawn with Swift Charts rather than the hand-rolled ``Sparkline``: two
/// series on different scales need real axes and a legend, and inventing
/// those by hand would be worse than the framework's. The house rules still
/// apply — too little data draws nothing, and the whole thing is described in
/// words for anyone not reading it by eye.
struct SleepMoodChart: View {
    let points: [SleepMoodPoint]

    /// Matches ``Sparkline``. Two nights and two moods is not a pattern, and
    /// drawing it as one is the exact mistake this app exists to avoid.
    var minimumPairedDays: Int = 3

    /// Sleep is plotted in hours and mood on the app's 0–10 scale, so mood is
    /// mapped onto the sleep axis to share a plot area. Fourteen hours is a
    /// generous but real ceiling; anything above it is almost certainly a
    /// mis-entry rather than a night's sleep.
    private let sleepCeiling: Double = 14
    private let moodCeiling: Double = 10

    private var pairedCount: Int {
        points.filter(\.isPaired).count
    }

    var body: some View {
        if pairedCount < minimumPairedDays {
            notEnoughYet
        } else {
            VStack(alignment: .leading, spacing: 12) {
                legend
                chart
            }
        }
    }

    // MARK: - Empty state

    private var notEnoughYet: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 13))
                .foregroundStyle(Vida.sage)
            Text(pairedCount == 0
                 ? "No check-ins yet. Your sleep and mood pattern appears after a few days of tracking."
                 : "\(pairedCount) day\(pairedCount == 1 ? "" : "s") logged · \(minimumPairedDays) needed before Vida will draw this.")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.taupe)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Vida.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Legend

    /// Hand-drawn rather than the framework's, so the two series carry the
    /// same colours and wording as the rest of the app.
    private var legend: some View {
        HStack(spacing: 16) {
            legendKey(SignalCategory.sleep.accent, "Sleep (hours)")
            legendKey(SignalCategory.mood.accent, "Mood (0–10)")
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private func legendKey(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label)
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(points.filter { $0.sleepHours != nil }) { point in
                LineMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Sleep", point.sleepHours ?? 0),
                    series: .value("Series", "Sleep")
                )
                .foregroundStyle(SignalCategory.sleep.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

            ForEach(points.filter { $0.mood != nil }) { point in
                LineMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Mood", scaledMood(point.mood ?? 0)),
                    series: .value("Series", "Mood")
                )
                .foregroundStyle(SignalCategory.mood.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartYScale(domain: 0...sleepCeiling)
        .chartYAxis {
            // Left axis reads in hours, which is what sleep is actually
            // measured in. The right axis re-labels the same gridlines back
            // into mood's own 0–10, so neither series is shown on a scale
            // that isn't its own.
            AxisMarks(position: .leading, values: [0, 4, 8, 12]) { value in
                AxisGridLine().foregroundStyle(Vida.hairline)
                AxisValueLabel {
                    Text(value.as(Double.self).map { "\(Int($0))h" } ?? "")
                        .font(Vida.sans(11))
                        .foregroundStyle(Vida.taupe)
                }
            }
            AxisMarks(position: .trailing, values: [0, 4, 8, 12]) { value in
                AxisValueLabel {
                    Text(value.as(Double.self).map { "\(Int(unscaledMood($0)))" } ?? "")
                        .font(Vida.sans(11))
                        .foregroundStyle(Vida.taupe)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(Vida.sans(11))
                    .foregroundStyle(Vida.taupe)
            }
        }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep and mood over the last \(points.count) days")
        .accessibilityValue(spokenSummary)
    }

    private func scaledMood(_ mood: Double) -> Double {
        mood / moodCeiling * sleepCeiling
    }

    private func unscaledMood(_ scaled: Double) -> Double {
        scaled / sleepCeiling * moodCeiling
    }

    // MARK: - Spoken summary

    /// The relationship in words. Deliberately descriptive rather than causal
    /// — this is two averages, not a finding, and Vida's Pattern Map is where
    /// correlation gets tested properly.
    private var spokenSummary: String {
        let paired = points.filter(\.isPaired)
        guard !paired.isEmpty else { return "Not enough readings" }

        let sleeps = paired.compactMap(\.sleepHours)
        let moods = paired.compactMap(\.mood)
        let averageSleep = sleeps.reduce(0, +) / Double(sleeps.count)
        let averageMood = moods.reduce(0, +) / Double(moods.count)

        var summary = String(
            format: "%d days with both logged. Average sleep %.1f hours, average mood %.1f out of 10.",
            paired.count, averageSleep, averageMood
        )

        if let contrast = betterNightsContrast(paired) {
            summary += " " + contrast
        }
        return summary
    }

    /// Compares mood after the longer half of nights against the shorter half.
    /// Returns nil when the two halves are too close to say anything honest.
    private func betterNightsContrast(_ paired: [SleepMoodPoint]) -> String? {
        guard paired.count >= 4 else { return nil }
        let sorted = paired.sorted { ($0.sleepHours ?? 0) < ($1.sleepHours ?? 0) }
        let half = sorted.count / 2
        let shortNights = sorted.prefix(half).compactMap(\.mood)
        let longNights = sorted.suffix(half).compactMap(\.mood)
        guard !shortNights.isEmpty, !longNights.isEmpty else { return nil }

        let shortAverage = shortNights.reduce(0, +) / Double(shortNights.count)
        let longAverage = longNights.reduce(0, +) / Double(longNights.count)
        let difference = longAverage - shortAverage
        guard abs(difference) >= 0.5 else {
            return "Mood is about the same after longer and shorter nights."
        }

        return difference > 0
            ? String(format: "Mood averages %.1f higher after your longer nights.", difference)
            : String(format: "Mood averages %.1f lower after your longer nights.", -difference)
    }
}

extension SleepMoodPoint {
    /// Merges two signal series into one per-day timeline.
    ///
    /// Both series are keyed by day rather than zipped, because they are
    /// logged in different halves of the day and a straight zip would pair a
    /// Tuesday night with a Thursday mood the moment one day is missed.
    static func merge(
        sleep: [(Date, Double)],
        mood: [(Date, Double)],
        calendar: Calendar = .current
    ) -> [SleepMoodPoint] {
        var byDay: [Date: (sleep: Double?, mood: Double?)] = [:]

        for (date, value) in sleep {
            let day = calendar.startOfDay(for: date)
            byDay[day, default: (nil, nil)].sleep = value
        }
        for (date, value) in mood {
            let day = calendar.startOfDay(for: date)
            byDay[day, default: (nil, nil)].mood = value
        }

        return byDay
            .map { SleepMoodPoint(date: $0.key, sleepHours: $0.value.sleep, mood: $0.value.mood) }
            .sorted { $0.date < $1.date }
    }
}
