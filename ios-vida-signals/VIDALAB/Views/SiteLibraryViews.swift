import SwiftUI

// Screens for the content the website publishes: condition guides, the Vida
// Apothecary, the specialist directory, and Rowan's research. All read-only,
// all loaded through `SiteContentService`.

// MARK: - Shared pieces

/// Loading and failure states shared by every website-backed screen.
struct SiteContentStatus: View {
    let isLoading: Bool
    let failure: String?
    let retry: () -> Void

    var body: some View {
        if isLoading {
            ProgressView()
                .tint(Vida.moss)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .accessibilityLabel("Loading")
        } else if let failure {
            VStack(spacing: 14) {
                QuietEmptyState(symbol: "wifi.slash", title: "Couldn't load", message: failure)
                Button(action: retry) {
                    Text("Try again")
                        .font(Vida.sans(14, weight: .semibold))
                        .foregroundStyle(Vida.onForest)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(Vida.forest, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 30)
        }
    }
}

/// A row card that opens one of the website-backed sections from the Library.
struct LibraryLaunchCard: View {
    let symbol: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Vida.moss)
                    .frame(width: 44, height: 44)
                    .background(Vida.sage.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Vida.serif(19))
                        .foregroundStyle(Vida.forest)
                    Text(detail)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Vida.taupe)
            }
            .paperCard(padding: 18)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Sheet chrome shared by the website-backed screens: title, Done button.
private struct SiteSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            content
                .vidaBackground()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Vida.moss)
                    }
                }
        }
    }
}

private struct EducationalFootnote: View {
    var text = "Vida is for education and personal tracking. It does not diagnose conditions or replace urgent or professional care."

    var body: some View {
        Text(text)
            .font(Vida.sans(12))
            .foregroundStyle(Vida.taupe)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Condition guides

struct ConditionReportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let report: ConditionReport

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: report.categoryTitle, color: Vida.moss)
                        Text(report.name)
                            .font(Vida.serif(31))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                        if let summary = report.summary, !summary.isEmpty {
                            Text(summary)
                                .font(Vida.sans(16))
                                .foregroundStyle(Vida.inkSoft)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ForEach(report.sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(Vida.serif(21))
                                .foregroundStyle(Vida.forest)
                            MarkdownBlocks(markdown: section.body)
                        }
                    }

                    Link(destination: report.webURL) {
                        Label("Read on vidalab.co", systemImage: "arrow.up.right")
                            .font(Vida.sans(14, weight: .semibold))
                            .foregroundStyle(Vida.moss)
                            .frame(minHeight: 44)
                    }

                    EducationalFootnote()
                }
                .padding(24)
                .readableColumn()
            }
            .vidaBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Vida.moss)
                }
            }
        }
    }
}

// MARK: - Vida Apothecary

struct ApothecaryView: View {
    private let content = SiteContentService.shared
    @State private var shelf: ApothecaryShelf = .recipe
    @State private var query = ""
    @State private var selected: ApothecaryItem?

    private var items: [ApothecaryItem] {
        let all = content.apothecary.value ?? []
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty {
            return all.filter {
                $0.title.localizedStandardContains(term)
                    || ($0.summary ?? "").localizedStandardContains(term)
                    || $0.tags.contains { $0.localizedStandardContains(term) }
            }
        }
        return all.filter { $0.category == shelf.rawValue }
    }

    var body: some View {
        SiteSheet(title: "The Vida Apothecary") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipes, movement\nand rituals.")
                            .font(Vida.serif(28))
                            .foregroundStyle(Vida.forest)
                        Text("Gentle, evidence-informed practices from VIDA LAB, each with its sources.")
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 22)

                    if query.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 9) {
                                ForEach(ApothecaryShelf.allCases) { option in
                                    SelectChip(label: option.title, isSelected: shelf == option) {
                                        withAnimation(.snappy) { shelf = option }
                                    }
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .contentMargins(.horizontal, 22)
                    }

                    SiteContentStatus(
                        isLoading: content.apothecary.value == nil && !isFailed,
                        failure: failure,
                        retry: { Task { await content.loadApothecary(force: true) } }
                    )

                    if content.apothecary.value != nil {
                        if items.isEmpty {
                            QuietEmptyState(symbol: "magnifyingglass", title: "No matches", message: "Nothing in the Apothecary matches that search.")
                                .padding(.horizontal, 22)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(items) { item in
                                    Button { selected = item } label: { ApothecaryRow(item: item) }
                                        .buttonStyle(PressableStyle())
                                }
                            }
                            .padding(.horizontal, 22)
                        }
                    }
                }
                .padding(.vertical, 16)
                .readableColumn()
            }
            .searchable(text: $query, prompt: "Search the Apothecary")
        }
        .task { await content.loadApothecary() }
        .sheet(item: $selected) { item in
            // Full height: a half sheet left the list's own Done button
            // showing above this one's.
            ApothecaryItemView(item: item)
                .presentationDetents([.large])
        }
    }

    private var failure: String? {
        if case .failed(let message) = content.apothecary { return message }
        return nil
    }

    private var isFailed: Bool { failure != nil }
}

private struct ApothecaryRow: View {
    let item: ApothecaryItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: ApothecaryShelf(rawValue: item.category)?.symbol ?? "leaf")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Vida.moss)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .multilineTextAlignment(.leading)
                if !item.detailLine.isEmpty {
                    Text(item.detailLine)
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.taupe)
                }
                if let summary = item.summary, !summary.isEmpty {
                    Text(summary)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(3)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
        }
        .paperCard(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

struct ApothecaryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VidaStore.self) private var store
    let item: ApothecaryItem
    @State private var session: MeditationPlan?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: ApothecaryShelf(rawValue: item.category)?.title ?? "Apothecary", color: Vida.moss)
                        Text(item.title)
                            .font(Vida.serif(30))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                        if !item.detailLine.isEmpty {
                            Text(item.detailLine)
                                .font(Vida.sans(13))
                                .foregroundStyle(Vida.taupe)
                        }
                        if let summary = item.summary, !summary.isEmpty {
                            Text(summary)
                                .font(Vida.sans(16))
                                .foregroundStyle(Vida.inkSoft)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if item.category == ApothecaryShelf.meditation.rawValue {
                        Button {
                            if store.isPlus {
                                session = GuidedScript.breathPattern(forTitle: item.title).map(MeditationPlan.breathing) ?? .guided(item)
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            Label(store.isPlus ? "Start a guided session" : "Start a guided session with Vida+", systemImage: "play.fill")
                                .font(Vida.sans(15, weight: .semibold))
                                .foregroundStyle(Vida.onForest)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Vida.forest, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }

                    if let content = item.content, !content.isEmpty {
                        MarkdownBlocks(markdown: content)
                    }

                    if item.category == ApothecaryShelf.supplement.rawValue {
                        Text("Check with your doctor or pharmacist before starting a supplement, especially if you take other medicines, are pregnant, or have a health condition.")
                            .font(Vida.sans(13))
                            .foregroundStyle(Vida.forest)
                            .lineSpacing(4)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if let citations = item.citations, !citations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "Sources")
                            MarkdownBlocks(markdown: citations)
                        }
                    }

                    EducationalFootnote()
                }
                .padding(24)
                .readableColumn()
            }
            .vidaBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Vida.moss)
                }
            }
        }
        .fullScreenCover(item: $session) { MeditationSessionView(plan: $0) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

// MARK: - Specialist finder

struct SpecialistFinderView: View {
    private let content = SiteContentService.shared
    @State private var query = ""

    private var practices: [SpecialistPractice] {
        let all = content.specialists.value ?? []
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return all }
        return all.filter { practice in
            [practice.practiceName, practice.specialty, practice.category, practice.city, practice.state, practice.zipCode, practice.notes]
                .contains { ($0 ?? "").localizedStandardContains(term) }
        }
    }

    var body: some View {
        SiteSheet(title: "Find a specialist") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Practices VIDA LAB has gathered for people living with chronic conditions. Search by specialty, condition, city, state, or ZIP code.")
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 22)

                    SiteContentStatus(
                        isLoading: content.specialists.value == nil && failure == nil,
                        failure: failure,
                        retry: { Task { await content.loadSpecialists(force: true) } }
                    )

                    if content.specialists.value != nil {
                        if practices.isEmpty {
                            QuietEmptyState(symbol: "magnifyingglass", title: "No matches", message: "Try a broader search, like a specialty or a state.")
                                .padding(.horizontal, 22)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(practices) { SpecialistCard(practice: $0) }
                            }
                            .padding(.horizontal, 22)
                        }
                    }

                    EducationalFootnote(text: "Listings are for information only. VIDA LAB doesn't endorse any practice, and details can change, so confirm with the office before you go.")
                        .padding(.horizontal, 22)
                }
                .padding(.vertical, 16)
                .readableColumn()
            }
            .searchable(text: $query, prompt: "Specialty, city, or ZIP")
        }
        .task { await content.loadSpecialists() }
    }

    private var failure: String? {
        if case .failed(let message) = content.specialists { return message }
        return nil
    }
}

private struct SpecialistCard: View {
    let practice: SpecialistPractice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(practice.practiceName)
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                if let specialty = practice.specialty, !specialty.isEmpty {
                    Text(specialty)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                }
                let place = [practice.address, practice.cityLine].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: "\n")
                if !place.isEmpty {
                    Text(place)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.taupe)
                        .lineSpacing(3)
                }
                if practice.acceptingNewPatients == true {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle")
                            .accessibilityHidden(true)
                        Text("Accepting new patients")
                    }
                    .font(Vida.sans(12, weight: .medium))
                    .foregroundStyle(Vida.moss)
                    .padding(.top, 2)
                }
            }

            HStack(spacing: 8) {
                if let phone = practice.phoneURL {
                    action("Call", symbol: "phone", url: phone, spoken: "Call \(practice.practiceName)")
                }
                if let website = practice.websiteURL {
                    action("Website", symbol: "safari", url: website, spoken: "\(practice.practiceName) website")
                }
                DirectionsMenu(
                    name: practice.practiceName,
                    apple: practice.mapsURL,
                    google: GoogleMapsLink.directions(to: [practice.practiceName, practice.address, practice.cityLine].compactMap { $0 }.joined(separator: ", "))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 16)
    }

    /// A full 44-point target, spoken with the practice name rather than the
    /// icon's own name ("Safari", "Show Map").
    private func action(_ title: String, symbol: String, url: URL, spoken: String) -> some View {
        Link(destination: url) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(Vida.sans(13, weight: .semibold))
            .foregroundStyle(Vida.moss)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Vida.sage.opacity(0.16), in: Capsule())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isLink)
    }
}

// MARK: - Rowan's research

struct ResearchPapersView: View {
    private let content = SiteContentService.shared

    var body: some View {
        SiteSheet(title: "Rowan's research") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Original research by VIDA LAB founder Rowan Albritton.")
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 22)

                    SiteContentStatus(
                        isLoading: content.papers.value == nil && failure == nil,
                        failure: failure,
                        retry: { Task { await content.loadPapers(force: true) } }
                    )

                    ForEach(content.papers.value ?? []) { paper in
                        VStack(alignment: .leading, spacing: 10) {
                            let meta = [paper.program, paper.year].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
                            if !meta.isEmpty { Eyebrow(text: meta, color: Vida.moss) }
                            Text(paper.title)
                                .font(Vida.serif(21))
                                .foregroundStyle(Vida.forest)
                                .fixedSize(horizontal: false, vertical: true)
                            if let abstract = paper.abstract, !abstract.isEmpty {
                                Text(abstract)
                                    .font(Vida.sans(14))
                                    .foregroundStyle(Vida.inkSoft)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let url = paper.documentURL {
                                Link(destination: url) {
                                    Label("Read the paper", systemImage: "doc.text")
                                        .font(Vida.sans(14, weight: .semibold))
                                        .foregroundStyle(Vida.moss)
                                        .frame(minHeight: 44)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paperCard(padding: 18)
                        .padding(.horizontal, 22)
                    }
                }
                .padding(.vertical, 16)
                .readableColumn()
            }
        }
        .task { await content.loadPapers() }
    }

    private var failure: String? {
        if case .failed(let message) = content.papers { return message }
        return nil
    }
}
