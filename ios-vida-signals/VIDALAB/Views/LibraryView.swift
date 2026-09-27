import SwiftUI

struct LibraryView: View {
    @Environment(VidaStore.self) private var store
    @State private var pillar: ScienceArticle.Pillar?
    @State private var article: ScienceArticle?
    @State private var showPaywall: Bool = false
    @State private var showConditions: Bool = false
    @State private var showApothecary: Bool = false
    @State private var showSpecialists: Bool = false
    @State private var showPapers: Bool = false
    @State private var query: String = ""

    private var filtered: [ScienceArticle] {
        var items = ScienceLibrary.articles
        if let pillar {
            items = items.filter { $0.pillar == pillar }
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            items = items.filter {
                $0.title.localizedStandardContains(trimmed) || $0.deck.localizedStandardContains(trimmed)
            }
        }
        return LibraryRanking.ordered(items, profile: store.profile)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    ConditionsLibraryLaunchCard { showConditions = true }
                    siteSections
                    pillarFilter
                    if isBrowsingEverything { forYouSection }
                    if !store.savedArticleIDs.isEmpty && isBrowsingEverything {
                        savedSection
                    }
                    articleList
                    if !store.isPlus { libraryNote }
                }
                .padding(.bottom, 40)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .searchable(text: $query, prompt: "Search the library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("THE LIBRARY")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Vida.forest)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
        .sheet(item: $article) { ArticleView(article: $0) }
        .sheet(isPresented: $showConditions) { ConditionsLibraryView() }
        .sheet(isPresented: $showApothecary) { ApothecaryView() }
        .sheet(isPresented: $showSpecialists) { SpecialistFinderView() }
        .sheet(isPresented: $showPapers) { ResearchPapersView() }
        // Early, so the directory card shows the real guide count.
        .task { await SiteContentService.shared.loadConditions() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Real stories meet\nreal science.")
                .font(Vida.serif(30))
                .foregroundStyle(Vida.forest)
            Text("Research translated into language that respects your intelligence. Every piece cites its sources.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 6)
    }

    /// The rest of what vidalab.co publishes, read from the same source as
    /// the site so the two never drift apart.
    private var siteSections: some View {
        VStack(spacing: 10) {
            LibraryLaunchCard(
                symbol: "leaf",
                title: "The Vida Apothecary",
                detail: "Recipes, movement, meditations and rituals"
            ) { showApothecary = true }
            LibraryLaunchCard(
                symbol: "stethoscope",
                title: "Find a specialist",
                detail: "Practices for chronic conditions, by specialty or place"
            ) { showSpecialists = true }
            LibraryLaunchCard(
                symbol: "doc.text.magnifyingglass",
                title: "Rowan's research",
                detail: "Original papers from VIDA LAB's founder"
            ) { showPapers = true }
        }
        .padding(.horizontal, 22)
    }

    private var isBrowsingEverything: Bool {
        pillar == nil && query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Pieces matched to the conditions she named in orientation. Shown first,
    /// because a woman with POTS should not have to scroll past cycle science
    /// to find something written about her.
    private var recommended: [ScienceArticle] {
        store.profile.recommendedArticleIDs.compactMap { ScienceLibrary.article(id: $0) }
    }

    @ViewBuilder
    private var forYouSection: some View {
        if !recommended.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeading(
                    eyebrow: "Matched to your health picture",
                    title: "For you"
                )
                .padding(.horizontal, 24)

                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(recommended) { item in
                            Button { open(item) } label: {
                                RecommendedCard(
                                    article: item,
                                    isLocked: item.isPremium && !store.isPlus
                                )
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 22)
            }
        }
    }

    private var pillarFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                SelectChip(label: "All", isSelected: pillar == nil) {
                    withAnimation(.snappy) { pillar = nil }
                }
                ForEach(ScienceArticle.Pillar.allCases) { item in
                    SelectChip(label: item.rawValue, isSelected: pillar == item) {
                        withAnimation(.snappy) { pillar = pillar == item ? nil : item }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 22)
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: "Yours", title: "Saved")
                .padding(.horizontal, 24)
            VStack(spacing: 10) {
                ForEach(ScienceLibrary.articles.filter { store.savedArticleIDs.contains($0.id) }) { item in
                    Button { open(item) } label: {
                        ArticleRow(article: item, isLocked: item.isPremium && !store.isPlus)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var articleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(eyebrow: pillar?.rawValue ?? "Everything", title: "\(filtered.count) piece\(filtered.count == 1 ? "" : "s")")
                .padding(.horizontal, 24)

            if filtered.isEmpty {
                // A dead search is the easiest place to strand someone, so
                // this states what was searched and offers the way back.
                VStack(spacing: 14) {
                    QuietEmptyState(
                        symbol: "magnifyingglass",
                        title: "No matches",
                        message: query.trimmingCharacters(in: .whitespaces).isEmpty
                            ? "There's nothing in this section yet."
                            : "Nothing in the library matches \u{201C}\(query.trimmingCharacters(in: .whitespaces))\u{201D}\(pillar != nil ? " in \(pillar?.rawValue ?? "")" : "")."
                    )

                    Button {
                        withAnimation(.snappy) {
                            query = ""
                            pillar = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Browse everything")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .font(Vida.sans(14, weight: .semibold))
                        .foregroundStyle(Vida.onForest)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(Vida.forest, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 22)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                        if index == 0 && isBrowsingEverything && recommended.isEmpty {
                            Button { open(item) } label: {
                                FeatureCard(article: item)
                            }
                            .buttonStyle(PressableStyle())
                        } else {
                            Button { open(item) } label: {
                                ArticleRow(article: item, isLocked: item.isPremium && !store.isPlus)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private var libraryNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 14))
                .foregroundStyle(Vida.moss)
            Text("\(freeCount) of \(ScienceLibrary.articles.count) pieces are open on Vida Free, in full, with every citation.")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private var freeCount: Int {
        ScienceLibrary.articles.filter { !$0.isPremium }.count
    }

    private func open(_ item: ScienceArticle) {
        if item.isPremium && !store.isPlus {
            showPaywall = true
        } else {
            article = item
        }
    }
}


// MARK: - Conditions directory

struct ConditionsLibraryLaunchCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // "cross.case.text" isn't an SF Symbol, which left this circle blank.
                Image(systemName: "cross.case")
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(Vida.cream)
                    .frame(width: 44, height: 44)
                    .background(Vida.forest, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Conditions directory")
                        .font(Vida.serif(20))
                        .foregroundStyle(Vida.forest)
                    Text("\(SiteContentService.shared.conditions.value?.count ?? ConditionGuide.all.count) conditions, with trusted next steps")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Vida.taupe)
            }
            .paperCard(padding: 18)
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal, 22)
    }
}

struct ConditionsLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    private let content = SiteContentService.shared
    @State private var query = ""
    @State private var selected: ConditionGuide?
    @State private var selectedReport: ConditionReport?

    /// The website's full guides, filtered by the search.
    private var filteredReports: [ConditionReport] {
        let all = content.conditions.value ?? []
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return all }
        return all.filter {
            $0.name.localizedStandardContains(term)
                || $0.categoryTitle.localizedStandardContains(term)
                || ($0.summary ?? "").localizedStandardContains(term)
        }
    }

    private var isLoadingReports: Bool {
        switch content.conditions {
        case .idle, .loading: true
        case .loaded, .failed: false
        }
    }

    private var filtered: [ConditionGuide] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return ConditionGuide.all }
        return ConditionGuide.all.filter {
            $0.name.localizedStandardContains(term) || $0.system.title.localizedStandardContains(term)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if content.conditions.value != nil {
                    List(filteredReports) { report in
                        Button { selectedReport = report } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(report.name)
                                    .font(Vida.sans(16, weight: .semibold))
                                    .foregroundStyle(Vida.forest)
                                Text(report.categoryTitle)
                                    .font(Vida.sans(13))
                                    .foregroundStyle(Vida.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else if isLoadingReports {
                    ProgressView()
                        .tint(Vida.moss)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Offline with nothing cached: the built-in directory
                    // still gives names and trusted next steps.
                    List(filtered) { guide in
                        Button { selected = guide } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(guide.name)
                                    .font(Vida.sans(16, weight: .semibold))
                                    .foregroundStyle(Vida.forest)
                                Text(guide.system.title)
                                    .font(Vida.sans(13))
                                    .foregroundStyle(Vida.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Search conditions")
            .navigationTitle("Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Vida.moss)
                }
            }
        }
        .task { await content.loadConditions() }
        .sheet(item: $selected) { ConditionGuideDetailView(guide: $0) }
        .sheet(item: $selectedReport) { report in
            ConditionReportDetailView(report: report)
                .presentationDetents([.large])
        }
    }
}

struct ConditionGuideDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let guide: ConditionGuide

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(guide.system.title.uppercased())
                            .font(Vida.sans(11, weight: .semibold))
                            .tracking(1.3)
                            .foregroundStyle(Vida.moss)
                        Text(guide.name)
                            .font(Vida.serif(31))
                            .foregroundStyle(Vida.forest)
                    }

                    ConditionGuideSection(
                        title: "What it is",
                        text: guide.system.overview
                    )
                    ConditionGuideSection(
                        title: "How to seek care",
                        text: guide.system.seekCare
                    )
                    ConditionGuideSection(
                        title: "Treatment options",
                        text: guide.system.treatmentOverview
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Read the current evidence")
                            .font(Vida.serif(20))
                            .foregroundStyle(Vida.forest)
                        Text("Open the NIH MedlinePlus entry for \(guide.name) for condition-specific symptoms, testing, and treatment information. Treatment choices depend on your history and should be made with a licensed clinician.")
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(5)
                        Link(destination: guide.sourceURL) {
                            Label("Open NIH MedlinePlus", systemImage: "arrow.up.right.square")
                                .font(Vida.sans(15, weight: .semibold))
                                .foregroundStyle(Vida.onForest)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Vida.forest, in: Capsule())
                        }
                    }
                    .padding(18)
                    .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("Vida is for education and personal tracking. It does not diagnose conditions or replace urgent or professional care.")
                        .font(Vida.sans(12))
                        .foregroundStyle(Vida.taupe)
                        .lineSpacing(4)
                }
                .padding(24)
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

struct ConditionGuideSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(Vida.serif(21))
                .foregroundStyle(Vida.forest)
            Text(text)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .lineSpacing(5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum ConditionSystem: String, CaseIterable {
    case brain, heart, breathing, digestion, immune, metabolic, movement, mentalHealth, urinary, reproductive

    var title: String {
        switch self {
        case .brain: "Brain, nerves & sleep"
        case .heart: "Heart & circulation"
        case .breathing: "Lungs & breathing"
        case .digestion: "Digestion & liver"
        case .immune: "Immune & inflammatory"
        case .metabolic: "Hormones & metabolism"
        case .movement: "Bones, joints & movement"
        case .mentalHealth: "Mental health"
        case .urinary: "Kidneys, bladder & urinary health"
        case .reproductive: "Reproductive & sexual health"
        }
    }

    var overview: String {
        "This is a \(title.lowercased()) condition. Its symptoms and severity can vary widely, so a diagnosis requires a clinician to assess your history, examination, and any appropriate testing."
    }

    var seekCare: String {
        "Start with primary care or the clinician who manages \(title.lowercased()). Bring a dated symptom record, changes you have noticed, medicines and supplements, and questions about testing or referral. Seek urgent care for sudden or severe symptoms, trouble breathing, chest pressure, new weakness, confusion, fainting, or thoughts of self-harm."
    }

    var treatmentOverview: String {
        "Treatment depends on the specific condition and your situation. A clinician may discuss monitoring, lifestyle supports, rehabilitation or therapy, medicines, procedures, or referral to a specialist. Do not start, stop, or change prescribed treatment based on this directory alone."
    }
}

struct ConditionGuide: Identifiable, Hashable {
    let name: String
    let system: ConditionSystem

    var id: String { name.lowercased() }
    var sourceURL: URL {
        var components = URLComponents(string: "https://medlineplus.gov/search/")
        components?.queryItems = [URLQueryItem(name: "query", value: name)]
        return components?.url ?? URL(string: "https://medlineplus.gov")!
    }

    static let all: [ConditionGuide] = {
        func make(_ names: [String], _ system: ConditionSystem) -> [ConditionGuide] {
            names.map { ConditionGuide(name: $0, system: system) }
        }

        return make([
            "ADHD", "Alzheimer's disease", "Bell's palsy", "Brain injury", "Carpal tunnel syndrome",
            "Cluster headache", "Dementia", "Epilepsy", "Essential tremor", "Guillain-Barré syndrome",
            "Migraine", "Multiple sclerosis", "Parkinson's disease", "Peripheral neuropathy", "Restless legs syndrome",
            "Sciatica", "Seizure disorders", "Sleep apnea", "Stroke", "Tension headache"
        ], .brain)
        + make([
            "Atrial fibrillation", "Cardiomyopathy", "Coronary artery disease", "Deep vein thrombosis", "Heart failure",
            "High blood pressure", "High cholesterol", "Peripheral artery disease", "Postural orthostatic tachycardia syndrome",
            "Pulmonary embolism", "Raynaud's phenomenon", "Tachycardia", "Varicose veins"
        ], .heart)
        + make([
            "Allergic rhinitis", "Asthma", "Bronchiectasis", "Chronic bronchitis", "Chronic obstructive pulmonary disease",
            "Cystic fibrosis", "Influenza", "Long COVID", "Pneumonia", "Pulmonary hypertension", "Sarcoidosis", "Tuberculosis"
        ], .breathing)
        + make([
            "Celiac disease", "Chronic constipation", "Crohn's disease", "Diverticular disease", "Fatty liver disease",
            "Gallstones", "Gastroesophageal reflux disease", "Gastroparesis", "Hepatitis", "Irritable bowel syndrome",
            "Pancreatitis", "Peptic ulcer disease", "Ulcerative colitis"
        ], .digestion)
        + make([
            "Ankylosing spondylitis", "Autoimmune hepatitis", "Behçet disease", "Dermatomyositis", "Fibromyalgia",
            "Lupus", "Myasthenia gravis", "Psoriasis", "Rheumatoid arthritis", "Scleroderma", "Sjögren syndrome", "Vasculitis"
        ], .immune)
        + make([
            "Anemia", "Cushing syndrome", "Diabetes", "Hashimoto thyroiditis", "Hyperthyroidism", "Hypothyroidism",
            "Metabolic syndrome", "Nonalcoholic fatty liver disease", "Osteoporosis", "Polycystic ovary syndrome",
            "Prediabetes", "Vitamin B12 deficiency", "Vitamin D deficiency"
        ], .metabolic)
        + make([
            "Back pain", "Bursitis", "Ehlers-Danlos syndromes", "Gout", "Hypermobility spectrum disorder",
            "Osteoarthritis", "Osteopenia", "Plantar fasciitis", "Rotator cuff injury", "Scoliosis", "Tendinitis", "Temporomandibular disorders"
        ], .movement)
        + make([
            "Anxiety disorders", "Bipolar disorder", "Depression", "Eating disorders", "Insomnia",
            "Obsessive-compulsive disorder", "Panic disorder", "Post-traumatic stress disorder", "Postpartum depression",
            "Seasonal affective disorder", "Social anxiety disorder", "Substance use disorder"
        ], .mentalHealth)
        + make([
            "Chronic kidney disease", "Interstitial cystitis", "Kidney stones", "Overactive bladder", "Polycystic kidney disease",
            "Prostatitis", "Urinary incontinence", "Urinary tract infection"
        ], .urinary)
        + make([
            "Adenomyosis", "Benign prostatic hyperplasia", "Erectile dysfunction", "Endometriosis", "Endometrial hyperplasia",
            "Heavy menstrual bleeding", "Infertility", "Menopause", "Pelvic inflammatory disease", "Premenstrual dysphoric disorder",
            "Premenstrual syndrome", "Uterine fibroids", "Vaginitis"
        ], .reproductive)
    }()
}

/// Compact card used in the horizontal "For you" rail.
struct RecommendedCard: View {
    let article: ScienceArticle
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: article.pillar.symbol)
                    .font(.system(size: 10))
                Text(article.pillar.rawValue.uppercased())
                    .font(Vida.sans(10, weight: .semibold))
                    .tracking(1.2)
                Spacer(minLength: 0)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                }
            }
            .foregroundStyle(Vida.moss)

            Text(article.title)
                .font(Vida.serif(19))
                .foregroundStyle(Vida.forest)
                .multilineTextAlignment(.leading)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("\(article.readMinutes) min read")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.taupe)
        }
        .frame(width: 210, alignment: .leading)
        .frame(height: 158)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Vida.paper)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Vida.moss.opacity(0.5))
                .frame(width: 2.5)
                .padding(.vertical, 18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Vida.hairline.opacity(0.6), lineWidth: 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ArticleRow: View {
    let article: ScienceArticle
    let isLocked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: article.pillar.symbol)
                        .font(.system(size: 10))
                    Text(article.pillar.rawValue.uppercased())
                        .font(Vida.sans(10, weight: .semibold))
                        .tracking(1.3)
                }
                .foregroundStyle(Vida.taupe)

                Text(article.title)
                    .font(Vida.serif(19))
                    .foregroundStyle(Vida.forest)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(article.readMinutes) min read")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.taupe)
            }

            Spacer(minLength: 0)

            Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                .font(.system(size: isLocked ? 12 : 12, weight: .semibold))
                .foregroundStyle(isLocked ? Vida.moss : Vida.taupe)
                .padding(.top, 20)
        }
        .paperCard(padding: 18)
    }
}

struct FeatureCard: View {
    let article: ScienceArticle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: article.pillar.symbol)
                    .font(.system(size: 10))
                Text(article.pillar.rawValue.uppercased())
                    .font(Vida.sans(10, weight: .semibold))
                    .tracking(1.3)
            }
            .foregroundStyle(Vida.moss)

            Text(article.title)
                .font(Vida.serif(24))
                .foregroundStyle(Vida.forest)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(article.deck)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                Text("Read")
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(Vida.sans(13, weight: .medium))
            .foregroundStyle(Vida.moss)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                .fill(Vida.paper)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Vida.skyDeep.opacity(0.5))
                .frame(width: 2.5)
                .padding(.vertical, 20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous)
                .strokeBorder(Vida.hairline.opacity(0.5), lineWidth: 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: Vida.cardRadius, style: .continuous))
    }
}

// MARK: - Article reader

struct ArticleView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let article: ScienceArticle

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 6) {
                            Image(systemName: article.pillar.symbol)
                                .font(.system(size: 11))
                            Text(article.pillar.rawValue.uppercased())
                                .font(Vida.sans(10, weight: .semibold))
                                .tracking(1.4)
                        }
                        .foregroundStyle(Vida.moss)

                        Text(article.title)
                            .font(Vida.serif(31))
                            .foregroundStyle(Vida.forest)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(article.deck)
                            .font(Vida.serif(18))
                            .italic()
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(article.readMinutes) min read")
                            .font(Vida.sans(12))
                            .foregroundStyle(Vida.taupe)
                    }
                    .padding(.top, 8)

                    HairlineDivider()

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(article.body.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph)
                                .font(Vida.sans(16))
                                .foregroundStyle(Vida.ink)
                                .lineSpacing(7)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    takeaways
                    citations
                    relatedTracking
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.toggleSave(article.id)
                    } label: {
                        Image(systemName: store.savedArticleIDs.contains(article.id) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15))
                            .foregroundStyle(Vida.moss)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Vida.sans(15, weight: .medium))
                        .foregroundStyle(Vida.moss)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
    }

    private var takeaways: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "What to take away", color: Vida.moss)
            ForEach(article.takeaways, id: \.self) { item in
                HStack(alignment: .top, spacing: 11) {
                    Circle()
                        .fill(Vida.moss)
                        .frame(width: 5, height: 5)
                        .padding(.top, 8)
                    Text(item)
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var citations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Sources")
            ForEach(article.citations) { citation in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(citation.authors) (\(citation.year))")
                        .font(Vida.sans(13, weight: .medium))
                        .foregroundStyle(Vida.ink)
                    Text(citation.title)
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(citation.journal)
                        .font(Vida.sans(12))
                        .italic()
                        .foregroundStyle(Vida.taupe)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var relatedTracking: some View {
        if !article.relatedCategories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HairlineDivider()
                Text("Track what you just read about")
                    .font(Vida.serif(19))
                    .foregroundStyle(Vida.forest)
                    .padding(.top, 8)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(article.relatedCategories) { category in
                        HStack(spacing: 6) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 11))
                                .foregroundStyle(category.accent)
                            Text(category.title)
                                .font(Vida.sans(13))
                                .foregroundStyle(Vida.inkSoft)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Vida.sage.opacity(0.16), in: Capsule())
                    }
                }
                Text("These signals appear in your daily check-in. Logging them is how this article becomes personal.")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
