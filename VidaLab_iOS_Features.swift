//
//  VidaLab_iOS_Features.swift
//  VIDA LAB — Feature Views (Daily Signals, Body Weather, Patterns, Trends, Experiments, Concierge, Doctors, Ask Vida)
//
//  Requires VidaLab_iOS_Core.swift in the same target.
//

import SwiftUI
import Charts

// MARK: - Daily Signals (Check-in)

struct DailySignalsView: View {
    @State private var energy = 3, mood = "neutral", sleepHours: Double = 7, sleepQuality = 3, painLevel = 0, cyclePhase = "not_tracking"
    @State private var symptoms: Set<String> = [], practices: Set<String> = [], notes = ""
    @State private var insight: String?, checkins: [CheckIn] = [], isLoading = false, error: String?
    private let moods = ["calm","happy","neutral","anxious","sad","irritable","motivated"]
    private let allSymptoms = ["headache","cramps","bloating","fatigue","breast_tenderness","acne","backache","nausea","brain_fog","cravings","none"]
    private let allPractices = ["meditation","gentle_exercise","anti_inflammatory_meal","supplement","breathing_exercise","nature_time","sleep_hygiene","hydration","gratitude","stretching"]

    var body: some View {
        Form {
            Section("Energy") { Stepper("Energy: \(energy)/5", value: $energy, in: 1...5) }
            Section("Sleep") { Slider(value: $sleepHours, in: 0...14, step: 0.5) { Text("Sleep: \(String(format: "%.1f", sleepHours)) hrs") }; Stepper("Quality: \(sleepQuality)/5", value: $sleepQuality, in: 1...5) }
            Section("Mood") { Picker("Mood", selection: $mood) { ForEach(moods, id: \.self) { Text($0.capitalized).tag($0) } } }
            Section("Pain") { Stepper("Pain: \(painLevel)/3", value: $painLevel, in: 0...3) }
            Section("Symptoms") { ForEach(allSymptoms, id: \.self) { s in Toggle(s.replacingOccurrences(of: "_", with: " ").capitalized, isOn: Binding(get: { symptoms.contains(s) }, set: { if $0 { symptoms.insert(s) } else { symptoms.remove(s) } })) } }
            Section("Practices") { ForEach(allPractices, id: \.self) { p in Toggle(p.replacingOccurrences(of: "_", with: " ").capitalized, isOn: Binding(get: { practices.contains(p) }, set: { if $0 { practices.insert(p) } else { practices.remove(p) } })) } }
            Section("Notes") { TextEditor(text: $notes) }
            if let i = insight { Section("Your Insight") { Text(i).italic().foregroundColor(Color(red: 0.24, green: 0.42, blue: 0.31)) } }
            if let e = error { Section { Text(e).foregroundColor(.red).font(.caption) } }
        }
        .navigationTitle("Daily Signals")
        .toolbar { Button("Save") { submit() }.disabled(isLoading) }
        .task { await loadHistory() }
    }

    private func submit() {
        isLoading = true; error = nil
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let body: [String: Any] = ["checkin_date": f.string(from: Date()), "energy": energy, "mood": mood, "sleep_hours": sleepHours, "sleep_quality": sleepQuality, "pain_level": painLevel, "cycle_phase": cyclePhase, "symptoms": Array(symptoms), "practices": Array(practices), "notes": notes]
        Task { do { let r = try await VidaAPIClient.shared.submitCheckin(body); insight = r.insight; await loadHistory() } catch { self.error = "Could not save." }; isLoading = false }
    }
    private func loadHistory() async { do { checkins = try await VidaAPIClient.shared.listEntities("DailyCheckin", sort: "-checkin_date", limit: 30) } catch {} }
}

// MARK: - Body Weather (Vida+)

struct BodyWeatherView: View {
    @State private var forecast: BodyWeatherForecast?, isLoading = false, message: String?, error: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading { ProgressView("Generating your forecast…").padding(.top, 60) }
                else if let e = error { Text(e).foregroundColor(.red).padding() }
                else if let m = message { Text(m).foregroundColor(.secondary).padding() }
                else if let f = forecast {
                    Text(f.summary).font(.system(size: 22, weight: .semibold, design: .serif)).foregroundColor(Color(red: 0.18, green: 0.27, blue: 0.24)).multilineTextAlignment(.center).padding(.horizontal)
                    if !f.patterns.isEmpty {
                        VStack(alignment: .leading, spacing: 8) { Text("Key Patterns").font(.headline); ForEach(f.patterns, id: \.self) { Text("• \($0)").font(.subheadline).foregroundColor(.secondary) } }
                        .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12)
                    }
                    ForEach(f.forecast) { day in ForecastDayCard(day: day) }
                    if !f.weekly_actions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) { Text("This Week").font(.headline); ForEach(f.weekly_actions, id: \.self) { Text("• \($0)").font(.subheadline).foregroundColor(.secondary) } }
                        .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12)
                    }
                    Text(f.disclaimer).font(.caption).foregroundColor(.secondary).padding()
                } else { Text("Your Body Weather forecast will appear here.").foregroundColor(.secondary).padding(.top, 60) }
            }
            .padding()
        }
        .navigationTitle("Body Weather").toolbar { Button("Refresh") { load() } }
        .task { if forecast == nil { load() } }
    }
    private func load() {
        isLoading = true; error = nil; message = nil
        Task { do { let r = try await VidaAPIClient.shared.getBodyWeather(); if r.status == "insufficient_data" { message = r.message } else if r.status == "ok" { forecast = r.forecast } } catch VidaAPIError.forbidden { error = "Vida+ membership required." } catch { self.error = "Could not generate forecast." }; isLoading = false }
    }
}

struct ForecastDayCard: View {
    let day: ForecastDay
    var riskColor: Color { switch day.risk_level { case "low": return .green; case "moderate": return .yellow; case "elevated": return .orange; case "high": return .red; default: return .gray } }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(day.day).font(.headline); Spacer(); Text(day.risk_level.capitalized).font(.caption).padding(.horizontal, 10).padding(.vertical, 4).background(riskColor.opacity(0.2)).foregroundColor(riskColor).cornerRadius(20) }
            Text(day.headline).font(.subheadline).fontWeight(.medium)
            Text(day.why).font(.caption).foregroundColor(.secondary)
            if !day.actions.isEmpty { VStack(alignment: .leading, spacing: 4) { ForEach(day.actions, id: \.self) { Text("→ \($0)").font(.caption).foregroundColor(Color(red: 0.24, green: 0.42, blue: 0.31)) } } }
        }
        .padding().background(Color(.systemGray6)).cornerRadius(12)
    }
}

// MARK: - Pattern Map (Vida+)

struct PatternMapView: View {
    @State private var checkins: [CheckIn] = [], isLoading = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading { ProgressView().padding(.top, 60) }
                else if checkins.isEmpty { Text("Log a few check-ins to see your patterns.").foregroundColor(.secondary).padding(.top, 60) }
                else {
                    Chart(checkins.reversed()) { c in LineMark(x: .value("Date", c.checkin_date), y: .value("Energy", c.energy)).foregroundStyle(.green) }.frame(height: 200).padding()
                    Chart(checkins.reversed().compactMap { c -> (String, Double)? in guard let s = c.sleep_hours else { return nil }; return (c.checkin_date, s) }, id: \.0) { item in LineMark(x: .value("Date", item.0), y: .value("Sleep", item.1)).foregroundStyle(.blue) }.frame(height: 200).padding()
                    Chart(checkins.reversed().compactMap { c -> (String, Double)? in guard let q = c.sleep_quality else { return nil }; return (c.checkin_date, Double(q)) }, id: \.0) { item in LineMark(x: .value("Date", item.0), y: .value("Quality", item.1)).foregroundStyle(.purple) }.frame(height: 200).padding()
                }
            }
        }
        .navigationTitle("Pattern Map").task { await load() }
    }
    private func load() async { isLoading = true; do { checkins = try await VidaAPIClient.shared.listEntities("DailyCheckin", sort: "-checkin_date", limit: 90) } catch {}; isLoading = false }
}

// MARK: - Trends

struct TrendsView: View {
    @State private var checkins: [CheckIn] = [], isLoading = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading { ProgressView().padding(.top, 60) }
                else if checkins.isEmpty { Text("Your trends will appear after a few weeks of tracking.").foregroundColor(.secondary).padding(.top, 60) }
                else {
                    VStack(alignment: .leading) { Text("Energy (90 days)").font(.headline).padding(.horizontal); Chart(checkins.reversed()) { c in LineMark(x: .value("Date", c.checkin_date), y: .value("Energy", c.energy)).foregroundStyle(.green) }.frame(height: 200).padding() }
                    VStack(alignment: .leading) { Text("Sleep Hours").font(.headline).padding(.horizontal); Chart(checkins.reversed().compactMap { c -> (String, Double)? in guard let s = c.sleep_hours else { return nil }; return (c.checkin_date, s) }, id: \.0) { item in LineMark(x: .value("Date", item.0), y: .value("Sleep", item.1)).foregroundStyle(.blue) }.frame(height: 200).padding() }
                    VStack(alignment: .leading) { Text("Mood Score").font(.headline).padding(.horizontal); Chart(checkins.reversed()) { c in LineMark(x: .value("Date", c.checkin_date), y: .value("Mood", moodScore(c.mood))).foregroundStyle(.orange) }.frame(height: 200).padding() }
                }
            }
        }
        .navigationTitle("Trends").task { await load() }
    }
    private func moodScore(_ m: String) -> Double { switch m { case "happy": return 5; case "calm","motivated": return 4; case "neutral": return 3; case "anxious","irritable": return 2; case "sad": return 1; default: return 3 } }
    private func load() async { isLoading = true; do { checkins = try await VidaAPIClient.shared.listEntities("DailyCheckin", sort: "-checkin_date", limit: 90) } catch {}; isLoading = false }
}

// MARK: - Vida Experiments (Vida+)

struct VidaExperimentsView: View {
    @State private var experiments: [Experiment] = [], isLoading = false, showCreate = false
    var body: some View {
        List { if isLoading { ProgressView() }; ForEach(experiments) { exp in NavigationLink(destination: ExperimentDetailView(experiment: exp)) {
            VStack(alignment: .leading, spacing: 4) { Text(exp.title).font(.headline); Text(exp.intervention).font(.caption).foregroundColor(.secondary)
                HStack { Text(exp.status.capitalized).font(.caption2).padding(.horizontal, 8).padding(.vertical, 3).background(exp.status == "active" ? .green.opacity(0.2) : .gray.opacity(0.2)).cornerRadius(20); Text("\(exp.duration_days) days").font(.caption2).foregroundColor(.secondary) } } } } }
        .navigationTitle("Experiments").toolbar { Button("New") { showCreate = true } }
        .sheet(isPresented: $showCreate) { CreateExperimentView { load() } }.task { await load() }
    }
    private func load() async { isLoading = true; do { experiments = try await VidaAPIClient.shared.listEntities("Experiment", sort: "-created_date", limit: 50) } catch {}; isLoading = false }
}

struct CreateExperimentView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = "", intervention = "", hypothesis = "", duration = 21, isLoading = false
    var onCreated: () -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") { TextField("e.g. Magnesium for sleep", text: $title) }
                Section("Intervention") { TextField("What you're testing", text: $intervention, axis: .vertical) }
                Section("Hypothesis") { TextField("What you think will happen", text: $hypothesis, axis: .vertical) }
                Section("Duration") { Stepper("\(duration) days", value: $duration, in: 7...90) }
            }
            .navigationTitle("New Experiment")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Create") { create() }.disabled(isLoading || title.isEmpty || intervention.isEmpty) } }
        }
    }
    private func create() {
        isLoading = true; let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; let start = f.string(from: Date()); let end = f.string(from: Calendar.current.date(byAdding: .day, value: duration, to: Date()) ?? Date())
        Task { do { let _: Experiment = try await VidaAPIClient.shared.createEntity("Experiment", body: ["title": title, "intervention": intervention, "hypothesis": hypothesis, "duration_days": duration, "start_date": start, "end_date": end, "status": "active", "metrics_to_watch": ["energy","sleep_hours","sleep_quality","mood","pain_level","symptoms"]]); onCreated(); dismiss() } catch {}; isLoading = false }
    }
}

struct ExperimentDetailView: View {
    let experiment: Experiment
    @State private var results: ExperimentResults?, isLoading = false, error: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) { Text(experiment.title).font(.title2.bold()); Text("Intervention: \(experiment.intervention)").font(.subheadline); Text("Hypothesis: \(experiment.hypothesis)").font(.subheadline).foregroundColor(.secondary); Text("Duration: \(experiment.duration_days) days").font(.caption).foregroundColor(.secondary) }
                .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12)
                if let r = results {
                    VStack(alignment: .leading, spacing: 12) { Text("Results").font(.headline); Text(r.verdict).font(.subheadline).fontWeight(.semibold); Text("Confidence: \(r.confidence.capitalized)").font(.caption).foregroundColor(.secondary); if let on = r.on_days_summary { Text("On days: \(on)").font(.caption) }; if let off = r.off_days_summary { Text("Off days: \(off)").font(.caption) }; ForEach(r.key_findings, id: \.self) { Text("• \($0)").font(.caption) }; if let recs = r.recommendations { Text("Next Steps").font(.caption).fontWeight(.semibold); ForEach(recs, id: \.self) { Text("→ \($0)").font(.caption).foregroundColor(.green) } }; Text(r.disclaimer).font(.caption2).foregroundColor(.secondary) }
                    .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12)
                }
                if let e = error { Text(e).foregroundColor(.red).font(.caption) }
                Button("Analyze Results") { analyze() }.buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.27, blue: 0.24)).disabled(isLoading)
                if isLoading { ProgressView() }
            }
            .padding()
        }
        .navigationTitle("Experiment")
    }
    private func analyze() {
        isLoading = true; error = nil
        Task { do { let r = try await VidaAPIClient.shared.getExperimentResults(experimentId: experiment.id); results = r.results } catch VidaAPIError.forbidden { error = "Vida+ required." } catch { self.error = "Not enough data yet." }; isLoading = false }
    }
}

// MARK: - Appointment Concierge (Vida+)

struct AppointmentConciergeView: View {
    @State private var prep: AppointmentConciergePrep?, isLoading = false, message: String?, error: String?, visitReason = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if prep == nil && !isLoading && !showGenerate {
                    Text("Generate a personalized visit prep guide based on your check-in patterns.").foregroundColor(.secondary).padding(.top, 60)
                    TextField("Reason for visit (optional)", text: $visitReason).textFieldStyle(.roundedBorder)
                    Button("Generate") { load() }.buttonStyle(.borderedProminent).tint(Color(red: 0.18, green: 0.27, blue: 0.24))
                } else if isLoading {
                    ProgressView("Preparing your visit guide…").padding(.top, 60)
                } else if let e = error {
                    Text(e).foregroundColor(.red).padding()
                } else if let m = message {
                    Text(m).foregroundColor(.secondary).padding()
                } else if let p = prep {
                    ConciergeSection(title: "Visit Summary", text: p.visit_summary)
                    ConciergeSection(title: "Your Symptom Narrative", text: p.symptom_narrative)
                    if let metrics = p.key_metrics, !metrics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) { Text("Key Metrics to Share").font(.headline); ForEach(metrics) { m in VStack(alignment: .leading, spacing: 2) { Text(m.label).font(.subheadline).fontWeight(.medium); Text(m.value).font(.caption).foregroundColor(.secondary); if let c = m.context { Text(c).font(.caption2).foregroundColor(.secondary) } } } }
                        .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12)
                    }
                    ConciergeList(title: "Questions to Ask", items: p.questions_to_ask)
                    if let t = p.tests_to_request { ConciergeList(title: "Tests to Ask About", items: t) }
                    ConciergeSection(title: "Advocacy Script", text: p.advocacy_script)
                    if let b = p.what_to_bring { ConciergeList(title: "What to Bring", items: b) }
                    Text(p.disclaimer).font(.caption2).foregroundColor(.secondary).padding()
                }
            }
            .padding()
        }
        .navigationTitle("Appointment Concierge").toolbar { if prep != nil { Button("Regenerate") { prep = nil; load() } } }
    }
    @State private var showGenerate = false
    private func load() {
        isLoading = true; error = nil; message = nil; showGenerate = true
        Task { do { let r = try await VidaAPIClient.shared.getAppointmentConcierge(conditionSlug: nil, visitReason: visitReason.isEmpty ? nil : visitReason); if r.status == "insufficient_data" { message = r.message } else if r.status == "ok" { prep = r.prep } } catch VidaAPIError.forbidden { error = "Vida+ required." } catch { self.error = "Could not generate." }; isLoading = false }
    }
}

struct ConciergeSection: View { let title: String; let text: String; var body: some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(text).font(.subheadline).foregroundColor(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12) } }
struct ConciergeList: View { let title: String; let items: [String]; var body: some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); ForEach(items, id: \.self) { Text("• \($0)").font(.subheadline).foregroundColor(.secondary) } }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12) } }

// MARK: - Doctor Finder

struct DoctorFinderView: View {
    @State private var doctors: [Doctor] = [], isLoading = false
    @State private var selectedCategory = "all"
    private let categories = ["all","autoimmune","neurological","cardiovascular","endocrine","musculoskeletal","gastrointestinal","respiratory","mental_health","chronic_pain","dysautonomia","gynecological","other"]
    var body: some View {
        List {
            Picker("Category", selection: $selectedCategory) { ForEach(categories, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }
            if isLoading { ProgressView() }
            ForEach(filtered) { doc in
                VStack(alignment: .leading, spacing: 4) {
                    Text(doc.practice_name).font(.headline)
                    Text(doc.specialty).font(.subheadline).foregroundColor(.secondary)
                    if let c = doc.city, let s = doc.state { Text("\(c), \(s)").font(.caption).foregroundColor(.secondary) }
                    if let p = doc.phone { Text("📞 \(p)").font(.caption) }
                    if let w = doc.website { Link("🌐 Website", destination: URL(string: w)!) }
                    if let a = doc.accepting_new_patients, a { Text("Accepting new patients").font(.caption2).foregroundColor(.green) }
                }
            }
        }
        .navigationTitle("Doctor Finder").task { await load() }
    }
    private var filtered: [Doctor] { selectedCategory == "all" ? doctors : doctors.filter { $0.category == selectedCategory } }
    private func load() async { isLoading = true; do { doctors = try await VidaAPIClient.shared.listEntities("Doctor", sort: "sort_order", limit: 500) } catch {}; isLoading = false }
}

// MARK: - Ask Vida (Vida+ AI Chat)

struct AskVidaView: View {
    @State private var messages: [ChatMessage] = [], input = "", isLoading = false, error: String?, conversationId: String?
    var body: some View {
        VStack {
            ScrollView { LazyVStack(spacing: 12) { ForEach(messages) { m in HStack { if m.isUser { Spacer() }; Text(m.content).padding(12).background(m.isUser ? Color(red: 0.18, green: 0.27, blue: 0.24) : Color(.systemGray5)).foregroundColor(m.isUser ? .white : .primary).cornerRadius(16); if !m.isUser { Spacer() } } }.padding() } }
            if let e = error { Text(e).font(.caption).foregroundColor(.red) }
            HStack { TextField("Ask Vida…", text: $input).textFieldStyle(.roundedBorder); Button(action: send) { if isLoading { ProgressView() } else { Image(systemName: "arrow.up.circle.fill").font(.title2) } }.disabled(isLoading || input.isEmpty) }.padding()
        }
        .navigationTitle("Ask Vida")
    }
    private func send() {
        let text = input; messages.append(ChatMessage(content: text, isUser: true)); input = ""; isLoading = true; error = nil
        Task { do { try await VidaAPIClient.shared.sendChatMessage(conversationId: conversationId ?? "create_via_agent", content: text) } catch VidaAPIError.forbidden { error = "Vida+ required." } catch { self.error = "Could not send." }; isLoading = false }
    }
}
struct ChatMessage: Identifiable { let id = UUID(); let content: String; let isUser: Bool }