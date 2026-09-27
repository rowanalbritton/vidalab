import Foundation
import HealthKit

/// Reads daily body metrics from Apple Health for the Body metrics screen.
///
/// Read-only and on demand: nothing here is saved to the journal, backed up,
/// or sent anywhere. Uses the same permission sheet as the Apple Health
/// connection (see `HealthImportService.readTypes`).
@MainActor
@Observable
final class BodyMetricsService {
    static let shared = BodyMetricsService()

    private let store: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    private(set) var series: [BodyMetricKind: BodyMetricSeries] = [:]
    private(set) var isLoading = false
    private(set) var lastLoaded: Date?

    var isAvailable: Bool { store != nil }

    /// Metrics that returned at least one day of data.
    var available: [BodyMetricSeries] {
        BodyMetricKind.allCases.compactMap { series[$0] }.filter { !$0.days.isEmpty }
    }

    /// Loads the last 30 days of every metric. Cheap to call again; skips
    /// work if it ran in the last five minutes unless forced.
    func load(force: Bool = false) async {
        guard let store else { return }
        if !force, let lastLoaded, Date.now.timeIntervalSince(lastLoaded) < 300 { return }
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let end = Date.now
        guard let start = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: end)) else { return }

        var loaded: [BodyMetricKind: BodyMetricSeries] = [:]
        for kind in BodyMetricKind.allCases {
            let days: [BodyMetricDay]
            if kind == .mindfulMinutes {
                days = (try? await mindfulDays(store: store, from: start, to: end, calendar: calendar)) ?? []
            } else {
                days = (try? await quantityDays(kind, store: store, from: start, to: end, calendar: calendar)) ?? []
            }
            loaded[kind] = BodyMetricSeries(kind: kind, days: days)
        }
        series = loaded
        lastLoaded = .now
    }

    private static func quantityType(_ kind: BodyMetricKind) -> (HKQuantityType, HKUnit)? {
        switch kind {
        case .restingHeartRate: (HKQuantityType(.restingHeartRate), HKUnit.count().unitDivided(by: .minute()))
        case .heartRateVariability: (HKQuantityType(.heartRateVariabilitySDNN), .secondUnit(with: .milli))
        case .respiratoryRate: (HKQuantityType(.respiratoryRate), HKUnit.count().unitDivided(by: .minute()))
        case .wristTemperature: (HKQuantityType(.appleSleepingWristTemperature), .degreeCelsius())
        case .oxygenSaturation: (HKQuantityType(.oxygenSaturation), .percent())
        case .steps: (HKQuantityType(.stepCount), .count())
        case .activeEnergy: (HKQuantityType(.activeEnergyBurned), .kilocalorie())
        case .mindfulMinutes: nil
        }
    }

    private func quantityDays(_ kind: BodyMetricKind, store: HKHealthStore, from start: Date, to end: Date, calendar: Calendar) async throws -> [BodyMetricDay] {
        guard let (type, unit) = Self.quantityType(kind) else { return [] }
        let predicate = HKSamplePredicate.quantitySample(
            type: type,
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: predicate,
            options: kind.isCumulative ? .cumulativeSum : .discreteAverage,
            anchorDate: calendar.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var days: [BodyMetricDay] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            let quantity = kind.isCumulative ? statistics.sumQuantity() : statistics.averageQuantity()
            guard var value = quantity?.doubleValue(for: unit) else { return }
            if kind == .oxygenSaturation { value *= 100 }
            days.append(BodyMetricDay(date: statistics.startDate, value: value))
        }
        return days
    }

    private func mindfulDays(store: HKHealthStore, from start: Date, to end: Date, calendar: Calendar) async throws -> [BodyMetricDay] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.mindfulSession), predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        var minutes: [Date: Double] = [:]
        for sample in samples {
            minutes[calendar.startOfDay(for: sample.startDate), default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 60
        }
        return minutes.keys.sorted().map { BodyMetricDay(date: $0, value: minutes[$0] ?? 0) }
    }
}
