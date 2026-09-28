import SwiftUI

/// Conversational access to Vida's curated, cited knowledge library.
struct AskVidaView: View {
    @Environment(VidaStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var query: String = ""
    @State private var thread: [Exchange] = []
    @State private var isThinking: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showQuotaAlert: Bool = false
    @State private var showLibrary: Bool = false
    @State private var article: ScienceArticle?
    @State private var sourcesFor: ScienceArticle?
    @State private var healthSummarySharingEnabled: Bool = false
    @State private var aiError: String?
    /// Set while the one-time AI permission prompt is waiting on an answer.
    @State private var pendingAIQuestion: String?
    @AppStorage(AIDisclosure.acceptedKey) private var aiDisclosureAccepted: Bool = false
    @AppStorage(FirstWeekGuide.askedKey) private var hasAskedQuestion: Bool = false
    @FocusState private var inputFocused: Bool

    struct Exchange: Identifiable, Equatable {
        let id = UUID()
        let question: String
        let outcome: AskOutcome
        var resonance: Resonance?

        enum Resonance: String { case yes = "Yes", sortOf = "Sort of", no = "No" }

        static func == (lhs: Exchange, rhs: Exchange) -> Bool { lhs.id == rhs.id }
    }

    private var authUserID: String? { auth.user?.id }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if thread.isEmpty {
                            intro
                            // The allowance is shown before she writes anything.
                            // Finding out you've spent your last question after
                            // composing it is a small betrayal.
                            if !store.isPlus { quotaNote }
                            suggestions
                        } else {
                            ForEach(thread) { exchange in
                                ExchangeBlock(
                                    exchange: exchange,
                                    onResonance: { mark(exchange, $0) },
                                    onRead: { article = $0 },
                                    onSources: { sourcesFor = $0 },
                                    onAsk: { submit($0) }
                                )
                                .id(exchange.id)
                            }
                            if isThinking { thinkingRow }
                            if !store.isPlus { quotaNote }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                .vidaScrollChrome("Ask Vida")
                .vidaMenu()
                .onChange(of: thread.count) { _, _ in
                    if let last = thread.last {
                        withAnimation(.smooth) { proxy.scrollTo(last.id, anchor: .top) }
                    }
                }
            }
            .vidaBackground()
            .safeAreaInset(edge: .bottom) { composer }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !thread.isEmpty {
                        Button {
                            withAnimation(.smooth) { thread = [] }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14))
                                .foregroundStyle(Vida.moss)
                        }
                        .accessibilityLabel("Start a new conversation")
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(item: $article) { ArticleView(article: $0) }
        .sheet(isPresented: $showLibrary) { LibraryView() }
        .sheet(item: $sourcesFor) { SourcesSheet(article: $0) }
        .task(id: authUserID) {
            guard let authUserID else {
                healthSummarySharingEnabled = false
                return
            }
            healthSummarySharingEnabled = await AskVidaAIService.healthSummarySharingEnabled(for: authUserID)
        }
        .alert("Ask Vida couldn't respond", isPresented: Binding(
            get: { aiError != nil },
            set: { if !$0 { aiError = nil } }
        )) {
            Button("OK", role: .cancel) { aiError = nil }
        } message: {
            Text(aiError ?? "Please try again.")
        }
        .alert("That's today's five questions", isPresented: $showQuotaAlert) {
            Button("Search the Library") { showLibrary = true }
            Button("See Vida+") { showPaywall = true }
            Button("Maybe later", role: .cancel) { }
        } message: {
            Text("Vida Free includes five questions a day, and they reset tomorrow morning at midnight. The full article library stays open and unlimited in the meantime.")
        }
        .alert(
            AIDisclosure.title,
            isPresented: Binding(
                get: { pendingAIQuestion != nil },
                set: { if !$0 { pendingAIQuestion = nil } }
            )
        ) {
            Button("Allow and ask") {
                guard let question = pendingAIQuestion else { return }
                pendingAIQuestion = nil
                aiDisclosureAccepted = true
                submit(question)
            }
            Button("Not now", role: .cancel) {
                // Declining still answers her, from the library, and costs
                // nothing from today's allowance — no question was sent.
                if let question = pendingAIQuestion {
                    withAnimation(.smooth(duration: 0.4)) {
                        thread.append(Exchange(question: question, outcome: .noMatch))
                    }
                    query = ""
                    inputFocused = false
                }
                pendingAIQuestion = nil
            }
        } message: {
            Text(AIDisclosure.message)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask anything\nabout your body.")
                .font(Vida.display(34))
                .tracking(Vida.displayTracking)
                .foregroundStyle(Vida.forest)
            Text("Vida answers from a curated library of peer-reviewed research — in plain language, with its sources shown. It won't diagnose you, and it won't guess.")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .vidaParallaxHeader()
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Start here")
            VStack(spacing: 10) {
                ForEach(AskVidaLibrary.suggested(for: store.profile.biologicalSex), id: \.self) { item in
                    Button {
                        submit(item)
                    } label: {
                        HStack(spacing: 12) {
                            Text(item)
                                .font(Vida.sans(15))
                                .foregroundStyle(Vida.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Vida.taupe)
                        }
                        .paperCard(padding: 16)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    private var thinkingRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Vida.sage)
                    .frame(width: 6, height: 6)
                    .scaleEffect(reduceMotion ? 0.8 : (isThinking ? 1.0 : 0.5))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.55).repeatForever().delay(Double(i) * 0.15),
                        value: isThinking
                    )
            }
            Text("Checking the library")
                .font(Vida.sans(13))
                .foregroundStyle(Vida.taupe)
        }
        .padding(.leading, 4)
        // Without this the dots are decorative and the state is silent:
        // VoiceOver would announce nothing while Vida is working.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Checking the library")
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Remaining allowance, plus the free way forward when it's gone.
    private var quotaNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "leaf")
                    .font(.system(size: 12))
                    .foregroundStyle(Vida.moss)
                Text(store.askRemaining > 0
                     ? "\(store.askRemaining) of \(VidaStore.freeAskLimit) questions left today"
                     : "Today's questions are used")
                    .font(Vida.sans(13, weight: .medium))
                    .foregroundStyle(Vida.ink)
                Spacer(minLength: 0)
                Button("Vida+") { showPaywall = true }
                    .font(Vida.sans(13, weight: .semibold))
                    .foregroundStyle(Vida.moss)
                    .buttonStyle(PressableStyle())
            }

            Text(store.askRemaining > 0
                 ? "They reset at midnight. The article library is always unlimited."
                 : "They reset at midnight. The article library is open and unlimited in the meantime.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if store.askRemaining == 0 {
                Button {
                    showLibrary = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 11))
                        Text("Search the Library instead")
                            .font(Vida.sans(13, weight: .semibold))
                    }
                    .foregroundStyle(Vida.forest)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Vida.paper, in: Capsule())
                    .overlay { Capsule().strokeBorder(Vida.hairline, lineWidth: 0.9) }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var canSend: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty && !isThinking
    }

    private var composer: some View {
        VStack(spacing: 0) {
            HairlineDivider()

            // Counter appears as she approaches the ceiling rather than after
            // the save fails.
            if query.count > AskGuardrails.questionLimit - 60 {
                HStack {
                    Spacer()
                    Text("\(query.count)/\(AskGuardrails.questionLimit)")
                        .font(Vida.number(11))
                        .foregroundStyle(query.count >= AskGuardrails.questionLimit ? Vida.clay : Vida.taupe)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            HStack(spacing: 10) {
                TextField("What do you want to understand?", text: $query, axis: .vertical)
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.ink)
                    .tint(Vida.moss)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .accessibilityLabel("Your question for Vida")
                    .onChange(of: query) { _, newValue in
                        if newValue.count > AskGuardrails.questionLimit {
                            query = String(newValue.prefix(AskGuardrails.questionLimit))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Vida.paper, in: Capsule())
                    .overlay { Capsule().strokeBorder(Vida.hairline, lineWidth: 0.9) }

                Button {
                    submit(query)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Vida.forest)
                            .frame(width: 44, height: 44)
                        if isThinking {
                            ProgressView()
                                .tint(Vida.onForest)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Vida.onForest)
                        }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableStyle())
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.4)
                .accessibilityLabel(isThinking ? "Checking the library" : "Send question")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Vida.cream)
    }

    private func submit(_ text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespaces).prefix(AskGuardrails.questionLimit))
        guard !trimmed.isEmpty, !isThinking else { return }
        // Ticks "Ask Vida a question" on the first-week checklist.
        hasAskedQuestion = true

        let outcome = AskGuardrails.classify(trimmed, sex: store.profile.biologicalSex)

        // Emergency and diagnosis/medication safeguards stay on-device and are
        // never sent to the AI service.
        if case .emergency = outcome {
            inputFocused = false
            query = ""
            withAnimation(.smooth(duration: 0.3)) {
                thread.append(Exchange(question: trimmed, outcome: outcome))
            }
            return
        }

        guard store.askRemaining > 0 else {
            inputFocused = false
            showQuotaAlert = true
            return
        }

        // Guideline 5.1.2(i): permission comes before the first question is
        // shared with a third-party AI, not after. Checked before the
        // allowance is spent, so asking permission never costs a question.
        if case .noMatch = outcome, !aiDisclosureAccepted {
            inputFocused = false
            pendingAIQuestion = trimmed
            return
        }

        inputFocused = false
        query = ""
        store.consumeAsk()

        guard case .noMatch = outcome else {
            withAnimation(.smooth(duration: 0.4)) {
                thread.append(Exchange(question: trimmed, outcome: outcome))
            }
            return
        }

        isThinking = true
        let summary = healthSummarySharingEnabled ? AskVidaAIService.approvedSummary(from: store) : nil
        Task {
            do {
                let answer = try await AskVidaAIService.answer(question: trimmed, healthSummary: summary)
                await MainActor.run {
                    isThinking = false
                    withAnimation(.smooth(duration: 0.4)) {
                        thread.append(Exchange(question: trimmed, outcome: .ai(answer)))
                    }
                }
            } catch {
                await MainActor.run {
                    isThinking = false
                    aiError = error.localizedDescription
                }
            }
        }
    }

    private func mark(_ exchange: Exchange, _ resonance: Exchange.Resonance) {
        guard let index = thread.firstIndex(of: exchange) else { return }
        withAnimation(.smooth) { thread[index].resonance = resonance }
    }
}

private struct ExchangeBlock: View {
    @Environment(VidaStore.self) private var store
    let exchange: AskVidaView.Exchange
    let onResonance: (AskVidaView.Exchange.Resonance) -> Void
    let onRead: (ScienceArticle) -> Void
    let onSources: (ScienceArticle) -> Void
    let onAsk: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(exchange.question)
                .font(Vida.serif(23))
                .foregroundStyle(Vida.forest)
                .fixedSize(horizontal: false, vertical: true)

            switch exchange.outcome {
            case .emergency(let guidance):
                EmergencyCard(guidance: guidance)
            case .outOfScope(let refusal):
                RefusalCard(refusal: refusal, onAsk: onAsk)
            case .answer(let answer):
                answerCard(answer)
            case .ai(let answer):
                aiAnswerCard(answer)
            case .noMatch:
                noMatchCard
            }
        }
    }

    @ViewBuilder
    private func answerCard(_ answer: VidaAnswer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
                    Text(answer.shortAnswer)
                        .font(Vida.sans(16, weight: .medium))
                        .foregroundStyle(Vida.ink)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Array(answer.detail.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let category = answer.trackSuggestion {
                        YourDataBlock(category: category)
                    }

                    if let articleID = answer.articleID, let article = ScienceLibrary.article(id: articleID) {
                        Button {
                            onRead(article)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: article.pillar.symbol)
                                    .font(.system(size: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Explore the science")
                                        .font(Vida.sans(11, weight: .semibold))
                                        .tracking(1.2)
                                        .foregroundStyle(Vida.taupe)
                                    Text(article.title)
                                        .font(Vida.sans(14, weight: .semibold))
                                        .foregroundStyle(Vida.forest)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 6)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Vida.moss)
                            }
                            .foregroundStyle(Vida.moss)
                            .padding(16)
                            .background(Vida.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }

            // An answer only exists if it can be cited, so this link always
            // resolves. `citedMatch` refuses to return anything else.
            if let articleID = answer.articleID, let article = ScienceLibrary.article(id: articleID) {
                Button {
                    onSources(article)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 11))
                        Text("View sources (\(article.citations.count))")
                            .font(Vida.sans(13, weight: .semibold))
                    }
                    .foregroundStyle(Vida.moss)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(Vida.paper, in: Capsule())
                    .overlay { Capsule().strokeBorder(Vida.hairline, lineWidth: 0.9) }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("View the \(article.citations.count) sources behind this answer")
            }

            HairlineDivider()

            resonanceBlock(answer)
        }
        .paperCard(padding: 20)
    }

    private func aiAnswerCard(_ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI-assisted educational guidance", systemImage: "sparkles")
                .font(Vida.sans(12, weight: .semibold))
                .foregroundStyle(Vida.moss)

            Text(answer)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Text("This is educational information, not a diagnosis or medical advice.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    private var noMatchCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("I don't have a researched answer for that yet.")
                .font(Vida.sans(16, weight: .medium))
                .foregroundStyle(Vida.ink)
            Text("Vida only answers from its curated, cited library — it won't improvise about your health. That's a deliberate limit, not a gap. Here's what it does cover:")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            SuggestionStack(
                items: Array(AskVidaLibrary.suggested(for: store.profile.biologicalSex).prefix(3)),
                onAsk: onAsk
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }

    @ViewBuilder
    private func resonanceBlock(_ answer: VidaAnswer) -> some View {
        if let resonance = exchange.resonance {
            VStack(alignment: .leading, spacing: 12) {
                Text(resonance == .no
                     ? "Good to know — your experience is the ground truth."
                     : "Then it's worth watching in your own data.")
                    .font(Vida.sans(14, weight: .medium))
                    .foregroundStyle(Vida.forest)
                    .fixedSize(horizontal: false, vertical: true)

                if resonance != .no, let category = answer.trackSuggestion {
                    HStack(spacing: 10) {
                        Image(systemName: category.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(category.accent)
                        Text("\(category.title) is in your daily check-in — log it and Vida will look for this pattern for you.")
                            .font(Vida.sans(13))
                            .foregroundStyle(Vida.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Does this sound like what you're experiencing?")
                    .font(Vida.sans(14, weight: .medium))
                    .foregroundStyle(Vida.ink)
                HStack(spacing: 8) {
                    ForEach([AskVidaView.Exchange.Resonance.yes, .sortOf, .no], id: \.rawValue) { option in
                        SelectChip(label: option.rawValue, isSelected: false) {
                            onResonance(option)
                        }
                    }
                }
            }
        }
    }
}

/// Urgent-symptom guidance, shown above everything else and never rationed.
///
/// Visually unlike anything else in the app on purpose: clay border, filled
/// header, no soft edges. If someone is skimming in a panic, this has to stop
/// the eye.
private struct EmergencyCard: View {
    let guidance: EmergencyGuidance

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(guidance.headline)
                    .font(Vida.sans(15, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Vida.onClay)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Vida.clay)

            VStack(alignment: .leading, spacing: 12) {
                Text(guidance.body)
                    .font(Vida.sans(15))
                    .foregroundStyle(Vida.ink)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Text(guidance.action)
                    .font(Vida.sans(13, weight: .medium))
                    .foregroundStyle(Vida.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .background(Vida.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Vida.clay, lineWidth: 1.4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A scripted refusal for diagnosis and medication questions, with a real way
/// forward attached. Vida declines the question, not the person.
private struct RefusalCard: View {
    let refusal: ScopeRefusal
    let onAsk: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 12))
                    .foregroundStyle(Vida.taupe)
                Text(refusal.headline)
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(refusal.body)
                .font(Vida.sans(15))
                .foregroundStyle(Vida.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            if !refusal.alternatives.isEmpty {
                Text("What Vida can help with:")
                    .font(Vida.sans(13, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                SuggestionStack(items: refusal.alternatives, onAsk: onAsk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 20)
    }
}

/// Tappable follow-up questions, shared by the refusal and no-match cards so
/// neither is ever a dead end.
private struct SuggestionStack: View {
    let items: [String]
    let onAsk: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onAsk(item)
                } label: {
                    HStack(spacing: 10) {
                        Text(item)
                            .font(Vida.sans(14))
                            .foregroundStyle(Vida.forest)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Vida.taupe)
                    }
                    .padding(14)
                    .frame(minHeight: 44)
                    .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

/// The citation list behind an answer.
///
/// Every substantive answer links here, and an answer that can't fill this
/// sheet is never produced in the first place.
struct SourcesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let article: ScienceArticle

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Behind this answer")
                        Text(article.title)
                            .font(Vida.serif(25))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)

                    ForEach(Array(article.citations.enumerated()), id: \.element.id) { index, citation in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(citation.authors) (\(citation.year))")
                                .font(Vida.sans(14, weight: .semibold))
                                .foregroundStyle(Vida.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(citation.title)
                                .font(Vida.sans(14))
                                .foregroundStyle(Vida.inkSoft)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(citation.journal)
                                .font(Vida.serifItalic(13))
                                .foregroundStyle(Vida.taupe)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paperCard(padding: 16)
                    }

                    Text("Vida summarises published research in plain language. A study describes a group of people; it can't tell you what's happening in your body. That's a conversation for you and a clinician.")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SOURCES")
                        .font(Vida.sans(12, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Vida.forest)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.moss)
                }
            }
            .toolbarBackground(Vida.cream, for: .navigationBar)
        }
    }
}

/// Grounds a library answer in the member's own logged data.
///
/// This is what separates Ask Vida from a search engine: the science is general,
/// but the numbers underneath it are hers. Shown only when there's enough data
/// to be honest about — below that it says so rather than inventing a trend.
private struct YourDataBlock: View {
    @Environment(VidaStore.self) private var store
    let category: SignalCategory

    private var readings: [(Date, Double)] { store.recentValues(for: category, days: 14) }

    private var average: Double {
        guard !readings.isEmpty else { return 0 }
        return readings.map(\.1).reduce(0, +) / Double(readings.count)
    }

    /// The strongest connection involving this signal, if Vida found one.
    private var relatedLink: PatternLink? {
        store.visibleInsights.first { $0.a == category || $0.b == category }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: category.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(category.accent)
                Eyebrow(text: "In your data", color: Vida.moss)
            }

            if readings.count >= 3 {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(averageText)
                        .font(Vida.number(26, weight: .regular))
                        .foregroundStyle(Vida.forest)
                    Text("average \(category.title.lowercased()) over \(readings.count) logged day\(readings.count == 1 ? "" : "s")")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Sparkline(values: readings.map(\.1), color: category.accent)
                    .frame(height: 34)

                if let link = relatedLink {
                    Text(PatternEngine.sentence(for: link, logs: store.visibleLogs))
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            } else {
                Text("You haven't logged \(category.title.lowercased()) enough times yet for Vida to say anything honest about your own pattern. A few more check-ins and this section fills in.")
                    .font(Vida.sans(13))
                    .foregroundStyle(Vida.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Vida.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var averageText: String {
        guard category == .sleep else { return String(format: "%.1f", average) }
        let hours = Int(average)
        let minutes = Int((average - Double(hours)) * 60)
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }
}
