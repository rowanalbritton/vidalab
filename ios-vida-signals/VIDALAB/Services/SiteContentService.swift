import Foundation
import Supabase

/// Loading state for one website collection.
enum SiteContentState<Value> {
    case idle
    case loading
    case loaded(Value)
    /// Nothing from the network and nothing cached. The message is for display.
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

/// Fetches the website's public content from Supabase and keeps an offline copy.
///
/// Each collection is fetched at most once per launch. A network failure falls
/// back to the last copy saved on this device, so the screens stay useful on a
/// plane; only a first launch with no connection shows an error.
@MainActor
@Observable
final class SiteContentService {
    static let shared = SiteContentService()

    private(set) var conditions: SiteContentState<[ConditionReport]> = .idle
    private(set) var apothecary: SiteContentState<[ApothecaryItem]> = .idle
    private(set) var specialists: SiteContentState<[SpecialistPractice]> = .idle
    private(set) var papers: SiteContentState<[ResearchPaper]> = .idle

    func loadConditions(force: Bool = false) async {
        guard force || conditions.value == nil else { return }
        conditions = .loading
        conditions = await Self.fetch("disease_reports", columns: ConditionReport.selectColumns, publicOnly: true, order: "name")
    }

    func loadApothecary(force: Bool = false) async {
        guard force || apothecary.value == nil else { return }
        apothecary = .loading
        apothecary = await Self.fetch("health_resources", columns: ApothecaryItem.selectColumns, publicOnly: true, order: "sort_order")
    }

    func loadSpecialists(force: Bool = false) async {
        guard force || specialists.value == nil else { return }
        specialists = .loading
        specialists = await Self.fetch("doctors", columns: SpecialistPractice.selectColumns, publicOnly: false, order: "sort_order")
    }

    func loadPapers(force: Bool = false) async {
        guard force || papers.value == nil else { return }
        papers = .loading
        papers = await Self.fetch("research_papers", columns: ResearchPaper.selectColumns, publicOnly: false, order: "sort_order")
    }

    private static func fetch<Row: Codable & Sendable>(
        _ table: String,
        columns: String,
        publicOnly: Bool,
        order: String
    ) async -> SiteContentState<[Row]> {
        do {
            var query = vidaSupabase.from(table).select(columns)
            if publicOnly { query = query.eq("is_public", value: true) }
            let rows: [Row] = try await query.order(order).execute().value
            if !rows.isEmpty { saveCache(rows, table: table) }
            return .loaded(rows)
        } catch {
            if let cached: [Row] = loadCache(table: table), !cached.isEmpty {
                return .loaded(cached)
            }
            return .failed("This couldn't load. Check your connection and try again.")
        }
    }

    private nonisolated static func cacheURL(_ table: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("site-\(table).json", isDirectory: false)
    }

    private nonisolated static func saveCache<Row: Encodable>(_ rows: [Row], table: String) {
        guard let data = try? JSONEncoder().encode(rows) else { return }
        try? data.write(to: cacheURL(table), options: .atomic)
    }

    private nonisolated static func loadCache<Row: Decodable>(table: String) -> [Row]? {
        guard let data = try? Data(contentsOf: cacheURL(table)) else { return nil }
        return try? JSONDecoder().decode([Row].self, from: data)
    }
}
