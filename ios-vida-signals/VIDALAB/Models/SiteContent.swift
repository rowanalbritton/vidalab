import Foundation

// Read-only content the website publishes through Supabase: the condition
// guides, the Vida Apothecary, the specialist directory, and Rowan's research.
// Every table here is public and edited on the site, so the app shows the same
// text vidalab.co does instead of keeping its own copy.
//
// Decoding is deliberately forgiving. These rows were imported from Base44,
// and some columns arrive as a number on one row and a string on the next
// (`duration_minutes`), or as a JSON array on one row and a Python-style list
// string on another (`tags`). One odd row must never empty a whole section.

/// A full condition guide from the website's library (`disease_reports`).
nonisolated struct ConditionReport: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let category: String?
    let summary: String?
    let overview: String?
    let symptoms: String?
    let diagnosis: String?
    let treatments: String?
    let resources: String?
    let doctorsGuide: String?
    let advocacyGuide: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, category, summary, overview, symptoms, diagnosis, treatments, resources
        case doctorsGuide = "doctors_guide"
        case advocacyGuide = "advocacy_guide"
    }

    static let selectColumns = "id,name,slug,category,summary,overview,symptoms,diagnosis,treatments,resources,doctors_guide,advocacy_guide"

    /// The site's category slug as a heading, e.g. "musculoskeletal" becomes
    /// "Musculoskeletal".
    var categoryTitle: String {
        guard let category, !category.isEmpty else { return "Other" }
        return category
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    /// The sections that have text, in reading order.
    var sections: [(title: String, body: String)] {
        [
            ("Overview", overview),
            ("Symptoms", symptoms),
            ("Diagnosis", diagnosis),
            ("Treatments", treatments),
            ("Which specialists to see", doctorsGuide),
            ("Advocating for yourself", advocacyGuide),
            ("Resources", resources),
        ].compactMap { title, body in
            guard let body = body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty else { return nil }
            return (title, body)
        }
    }

    var webURL: URL {
        URL(string: "https://vidalab.co/library/\(slug)") ?? URL(string: "https://vidalab.co/library")!
    }
}

/// One entry in the Vida Apothecary (`health_resources`).
nonisolated struct ApothecaryItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let category: String
    let subcategory: String?
    let summary: String?
    let content: String?
    let durationMinutes: Int?
    let difficulty: String?
    let tags: [String]
    let citations: String?

    enum CodingKeys: String, CodingKey {
        case id, title, category, subcategory, content, difficulty, tags, citations
        case summary = "description"
        case durationMinutes = "duration_minutes"
    }

    static let selectColumns = "id,title,category,subcategory,description,content,duration_minutes,difficulty,tags,citations"

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "habit"
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty)
        citations = try container.decodeIfPresent(String.self, forKey: .citations)
        durationMinutes = Self.flexibleInt(container, .durationMinutes)
        tags = Self.flexibleTags(container)
    }

    private static func flexibleInt(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(text.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func flexibleTags(_ container: KeyedDecodingContainer<CodingKeys>) -> [String] {
        if let list = try? container.decodeIfPresent([String].self, forKey: .tags) { return list }
        // "['quick', 'stress']", as written by the Base44 import.
        guard let text = try? container.decodeIfPresent(String.self, forKey: .tags) else { return [] }
        return text
            .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " '\"")) }
            .filter { !$0.isEmpty }
    }

    /// Shown under the title: "Breakfast · 5 min · Easy".
    var detailLine: String {
        var parts: [String] = []
        if let subcategory, !subcategory.isEmpty {
            parts.append(subcategory.replacingOccurrences(of: "-", with: " ").capitalized)
        }
        if let durationMinutes, durationMinutes > 0 { parts.append("\(durationMinutes) min") }
        // "Easy" means something for a recipe or a stretch, not a supplement.
        if let difficulty, !difficulty.isEmpty, category != ApothecaryShelf.supplement.rawValue {
            parts.append(difficulty.capitalized)
        }
        return parts.joined(separator: " · ")
    }
}

/// The Apothecary's five shelves, in the site's order.
nonisolated enum ApothecaryShelf: String, CaseIterable, Identifiable, Sendable {
    case recipe, exercise, meditation, habit, supplement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recipe: "Recipes"
        case .exercise: "Movement"
        case .meditation: "Meditations"
        case .habit: "Rituals"
        case .supplement: "Supplements"
        }
    }

    var symbol: String {
        switch self {
        case .recipe: "fork.knife"
        case .exercise: "figure.walk"
        case .meditation: "leaf"
        case .habit: "sun.horizon"
        case .supplement: "pills"
        }
    }
}

/// A specialist practice from the website's Doctor Finder (`doctors`).
nonisolated struct SpecialistPractice: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let practiceName: String
    let specialty: String?
    let category: String?
    let phone: String?
    let email: String?
    let address: String?
    let city: String?
    let state: String?
    let zipCode: String?
    let website: String?
    let acceptingNewPatients: Bool?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, specialty, category, phone, email, address, city, state, website, notes
        case practiceName = "practice_name"
        case zipCode = "zip_code"
        case acceptingNewPatients = "accepting_new_patients"
    }

    static let selectColumns = "id,practice_name,specialty,category,phone,email,address,city,state,zip_code,website,accepting_new_patients,notes"

    var cityLine: String {
        let place = [city, state].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: ", ")
        guard let zipCode, !zipCode.isEmpty else { return place }
        return place.isEmpty ? zipCode : "\(place) \(zipCode)"
    }

    var phoneURL: URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    var websiteURL: URL? {
        guard let website, !website.isEmpty else { return nil }
        return URL(string: website.hasPrefix("http") ? website : "https://\(website)")
    }

    var mapsURL: URL? {
        let query = [practiceName, address, cityLine].compactMap { $0 }.joined(separator: ", ")
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}

/// One of Rowan's research papers (`research_papers`).
nonisolated struct ResearchPaper: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let program: String?
    let year: String?
    let abstract: String?
    let fileURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, program, year, abstract
        case fileURL = "file_url"
    }

    static let selectColumns = "id,title,program,year,abstract,file_url"

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        program = try container.decodeIfPresent(String.self, forKey: .program)
        abstract = try container.decodeIfPresent(String.self, forKey: .abstract)
        fileURL = try container.decodeIfPresent(String.self, forKey: .fileURL)
        if let text = try? container.decodeIfPresent(String.self, forKey: .year) {
            year = text
        } else if let number = try? container.decodeIfPresent(Int.self, forKey: .year) {
            year = String(number)
        } else {
            year = nil
        }
    }

    var documentURL: URL? { fileURL.flatMap(URL.init(string:)) }
}
