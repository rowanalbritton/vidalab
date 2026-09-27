import SwiftUI
import CoreLocation
import EventKit
import EventKitUI
import MessageUI

// The Appointment Concierge's finding-and-booking tabs, matching the website's
// Doctor Finder: search near you, request an appointment, keep track of it.

enum ConciergeSection: String, CaseIterable, Identifiable {
    case prepare = "Prepare"
    case find = "Find a doctor"
    case appointments = "Appointments"

    var id: String { rawValue }
}

// MARK: - Find a doctor

struct ConciergeFinderPanel: View {
    @Binding var specialty: CareSpecialty
    let prep: ConciergeResult?
    let visitReason: String

    private let content = SiteContentService.shared
    @State private var customSpecialty = ""
    @State private var areaText = ""
    @State private var location: CLLocation?
    /// Where distances are measured from: her location, or the typed place.
    @State private var reference: CLLocation?
    @State private var directoryIsFar = false
    @State private var area: CareArea?
    @State private var directory: [CareProvider] = []
    @State private var nearby: [CareProvider] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var problem: String?
    @State private var requesting: CareProvider?
    @FocusState private var typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Who do you want to see?")
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(CareSpecialty.common) { option in
                            SelectChip(label: option.title, isSelected: specialty == option && customSpecialty.isEmpty) {
                                customSpecialty = ""
                                specialty = option
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                // Chips scroll past the column edge instead of being cut off.
                .scrollClipDisabled()
                field("Or type a specialty", text: $customSpecialty)
                    .onSubmit(search)
            }

            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Where?")
                Button(action: searchNearMe) {
                    Label(location == nil ? "Use my location" : "Using your location", systemImage: location == nil ? "location" : "location.fill")
                        .font(Vida.sans(15, weight: .semibold))
                        .foregroundStyle(Vida.moss)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Vida.sage.opacity(0.18), in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(isSearching)

                HStack(spacing: 8) {
                    field("City, state, or ZIP", text: $areaText)
                        .textContentType(.postalCode)
                        .submitLabel(.search)
                        .onSubmit(search)
                    Button(action: search) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Vida.onForest)
                            .frame(width: 50, height: 50)
                            .background(Vida.forest, in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(searchDisabled)
                    .opacity(searchDisabled ? 0.4 : 1)
                    .accessibilityLabel("Search")
                }
            }

            if isSearching {
                ProgressView("Looking for \(activeSpecialty.title.lowercased()) near \(area?.label ?? "you")")
                    .font(Vida.sans(13))
                    .tint(Vida.moss)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }

            if let problem {
                Text(problem)
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.forest)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Vida.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if hasSearched && !isSearching {
                results
            }
        }
        .sheet(item: $requesting) { provider in
            AppointmentRequestSheet(provider: provider, prep: prep, initialReason: visitReason)
                .presentationDetents([.large])
        }
        .task { await content.loadSpecialists() }
        .onChange(of: specialty) { _, _ in
            // Picking another specialty after a search re-runs it in place.
            guard hasSearched, !isSearching else { return }
            Task {
                isSearching = true
                await runSearch()
            }
        }
    }

    private var searchDisabled: Bool {
        isSearching || areaText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var activeSpecialty: CareSpecialty {
        let typed = customSpecialty.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? specialty : CareSpecialty.matching(typed)
    }

    @ViewBuilder
    private var results: some View {
        if directory.isEmpty && nearby.isEmpty {
            QuietEmptyState(
                symbol: "magnifyingglass",
                title: "No matches nearby",
                message: "Try a broader specialty, like primary care, or a nearby city."
            )
        }
        if !directory.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(eyebrow: "Curated by VIDA LAB", title: directoryIsFar ? "Closest in our directory" : "From our directory")
                if directoryIsFar {
                    Text("VIDA LAB's directory doesn't have a match close to you yet, so these are the nearest ones. The Apple Maps results below are closer.")
                        .font(Vida.sans(13))
                        .foregroundStyle(Vida.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(directory) { provider in
                    CareProviderCard(provider: provider, userLocation: reference) { requesting = provider }
                }
            }
        }
        if !nearby.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading(eyebrow: "From Apple Maps", title: "More near you")
                ForEach(nearby) { provider in
                    CareProviderCard(provider: provider, userLocation: reference) { requesting = provider }
                }
                Text("Listings come from Apple Maps. VIDA LAB hasn't reviewed them, so check that a practice treats what you need before you book.")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.taupe)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func field(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .font(Vida.sans(15))
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Vida.hairline, lineWidth: 0.9) }
            .focused($typing)
    }

    // MARK: Search

    private func searchNearMe() {
        typing = false
        Task {
            isSearching = true
            problem = nil
            do {
                let found = try await CareFinderService.currentLocation()
                location = found
                area = await CareFinderService.area(around: found)
                areaText = ""
                await runSearch()
            } catch CareFinderService.LocationProblem.denied {
                isSearching = false
                problem = "Location is off for VIDA LAB. Type a city or ZIP code instead, or turn it on in Settings > Privacy & Security > Location Services."
            } catch {
                isSearching = false
                problem = "Your location isn't available right now. Type a city or ZIP code instead."
            }
        }
    }

    private func search() {
        let typed = areaText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty || location != nil else { return }
        // Close the keyboard so the results aren't hidden under it.
        typing = false
        if !typed.isEmpty {
            location = nil
            area = CareArea.parse(typed)
        }
        Task {
            isSearching = true
            problem = nil
            await runSearch()
        }
    }

    private func runSearch() async {
        let specialty = activeSpecialty
        let searchArea = area ?? CareArea(label: areaText)
        let practices = content.specialists.value ?? []

        // One point to measure from: her location, or the place she typed.
        if let location {
            reference = location
        } else {
            reference = await CareFinderService.location(ofAddress: searchArea.label, cacheKey: "area:\(searchArea.label.lowercased())")
        }

        let candidates = CareMatcher.directoryMatches(practices, specialty: specialty, area: searchArea)
            .prefix(15)
            .map(CareProvider.init(directory:))
        if let reference {
            // The directory has addresses, not coordinates, so each match is
            // placed once (and cached) to measure a real distance.
            var placed: [CareProvider] = []
            for provider in candidates {
                let address = [provider.addressLine, provider.cityLine].compactMap { $0 }.joined(separator: ", ")
                if let spot = await CareFinderService.location(ofAddress: address, cacheKey: "doctor:\(provider.id)") {
                    placed.append(provider.placed(at: spot))
                }
            }
            let result = CareMatcher.nearest(placed, to: reference)
            directory = Array(result.providers.prefix(12))
            directoryIsFar = result.areFar
        } else {
            directory = Array(candidates.prefix(12))
            directoryIsFar = false
        }

        let mapResults = await CareFinderService.mapsResults(for: specialty, near: location, typedArea: searchArea.label)
        let directoryNames = Set(directory.map { $0.name.lowercased() })
        nearby = mapResults
            .filter { !directoryNames.contains($0.name.lowercased()) }
            .sorted { ($0.miles(from: reference) ?? .infinity) < ($1.miles(from: reference) ?? .infinity) }
        hasSearched = true
        isSearching = false
    }
}

struct CareProviderCard: View {
    let provider: CareProvider
    let userLocation: CLLocation?
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(provider.name)
                        .font(Vida.sans(16, weight: .semibold))
                        .foregroundStyle(Vida.forest)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if let miles = provider.miles(from: userLocation) {
                        Text(miles < 10 ? String(format: "%.1f mi", miles) : "\(Int(miles.rounded())) mi")
                            .font(Vida.sans(12, weight: .medium))
                            .foregroundStyle(Vida.taupe)
                    }
                }
                if let specialty = provider.specialty, !specialty.isEmpty {
                    Text(specialty).font(Vida.sans(13)).foregroundStyle(Vida.inkSoft)
                }
                let place = [provider.addressLine, provider.cityLine].compactMap { $0 }.joined(separator: "\n")
                if !place.isEmpty {
                    Text(place).font(Vida.sans(13)).foregroundStyle(Vida.taupe).lineSpacing(3)
                }
                if provider.acceptingNewPatients == true {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle").accessibilityHidden(true)
                        Text("Accepting new patients")
                    }
                    .font(Vida.sans(12, weight: .medium))
                    .foregroundStyle(Vida.moss)
                }
            }

            Button(action: onRequest) {
                Text("Request an appointment")
                    .font(Vida.sans(15, weight: .semibold))
                    .foregroundStyle(Vida.onForest)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())

            HStack(spacing: 8) {
                if let phone = provider.phoneURL {
                    ContactLink(title: "Call", symbol: "phone", url: phone, spoken: "Call \(provider.name)")
                }
                if let website = provider.websiteURL {
                    ContactLink(title: "Website", symbol: "safari", url: website, spoken: "\(provider.name) website")
                }
                if let maps = provider.mapsURL {
                    ContactLink(title: "Directions", symbol: "map", url: maps, spoken: "Directions to \(provider.name)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 16)
    }
}

/// A 44-point contact button, spoken with the practice name.
struct ContactLink: View {
    let title: String
    let symbol: String
    let url: URL
    let spoken: String

    var body: some View {
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

// MARK: - Request an appointment

struct AppointmentRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth
    @Environment(VidaStore.self) private var store

    let provider: CareProvider
    let prep: ConciergeResult?
    let initialReason: String

    @State private var preferred = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now) ?? .now
    @State private var reason = ""
    @State private var notes = ""
    @State private var includePrep = true
    @State private var remind = true
    @State private var isSaving = false
    @State private var failure: String?
    @State private var saved: AppointmentRecord?
    @State private var reminderScheduled = false
    @State private var showMail = false
    @State private var showCalendar = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: saved == nil ? "Request an appointment" : "Request saved", color: Vida.moss)
                        Text(provider.name)
                            .font(Vida.serif(26))
                            .foregroundStyle(Vida.forest)
                            .fixedSize(horizontal: false, vertical: true)
                        if let specialty = provider.specialty { Text(specialty).font(Vida.sans(14)).foregroundStyle(Vida.inkSoft) }
                    }
                    if let saved { nextSteps(for: saved) } else { form }
                }
                .padding(24)
                .readableColumn()
            }
            .scrollDismissesKeyboard(.interactively)
            .vidaBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saved == nil ? "Cancel" : "Done") { dismiss() }.foregroundStyle(Vida.moss)
                }
            }
        }
        .onAppear { if reason.isEmpty { reason = initialReason } }
        .sheet(isPresented: $showMail) {
            MailComposeSheet(
                recipient: provider.email ?? "",
                subject: AppointmentRequestEmail.subject(for: provider),
                body: emailBody
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCalendar) {
            CalendarEventSheet(
                title: "Appointment: \(provider.name)",
                start: preferred,
                location: [provider.addressLine, provider.cityLine].compactMap { $0 }.joined(separator: ", "),
                notes: reason
            )
            .ignoresSafeArea()
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "When would you like to go?")
                DatePicker("Preferred date and time", selection: $preferred, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    .font(Vida.sans(15))
                    .tint(Vida.moss)
                Text("The office sets the real time. This is your preference, and you can update it once they confirm.")
                    .font(Vida.sans(12))
                    .foregroundStyle(Vida.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            labeled("Reason for the visit", text: $reason, prompt: "For example, ongoing fatigue and headaches")
            labeled("Notes for yourself (optional)", text: $notes, prompt: "Insurance, questions, who referred you")

            if prep != nil && provider.email != nil {
                Toggle("Include my visit summary in the request email", isOn: $includePrep)
                    .font(Vida.sans(14, weight: .medium))
                    .tint(Vida.moss)
            }
            Toggle("Remind me the day before", isOn: $remind)
                .font(Vida.sans(14, weight: .medium))
                .tint(Vida.moss)

            if let failure {
                Text(failure).font(Vida.sans(14)).foregroundStyle(Vida.clay).fixedSize(horizontal: false, vertical: true)
            }

            Button(action: save) {
                HStack(spacing: 9) {
                    if isSaving { ProgressView().tint(Vida.onForest) }
                    Text("Save request")
                }
                .font(Vida.sans(16, weight: .semibold))
                .foregroundStyle(Vida.onForest)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Vida.forest, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(isSaving)

            Text("Saving keeps this request in your Appointments here and on vidalab.co. Next you can call, email, or book online to reach the office.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nextSteps(for record: AppointmentRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Saved to your Appointments for \(preferred.formatted(date: .abbreviated, time: .shortened)).\(reminderScheduled ? " We'll remind you the day before." : "") Now reach the office to book it:")
                .font(Vida.sans(15))
                .foregroundStyle(Vida.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let phone = provider.phoneURL {
                bigAction("Call to book", symbol: "phone.fill") { UIApplication.shared.open(phone) }
            }
            if provider.email != nil {
                bigAction("Email the request", symbol: "envelope.fill") {
                    if MFMailComposeViewController.canSendMail() {
                        showMail = true
                    } else if let url = mailtoURL {
                        UIApplication.shared.open(url)
                    }
                }
            }
            if let website = provider.websiteURL {
                bigAction("Book on their website", symbol: "safari.fill") { UIApplication.shared.open(website) }
            }
            bigAction("Add to Calendar", symbol: "calendar.badge.plus") { showCalendar = true }

            Text("When the office confirms, mark it confirmed in Appointments and update the time if it changed.")
                .font(Vida.sans(12))
                .foregroundStyle(Vida.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bigAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(Vida.sans(15, weight: .semibold))
                .foregroundStyle(Vida.forest)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Vida.sage.opacity(0.18), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func labeled(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(Vida.sans(12, weight: .semibold)).foregroundStyle(Vida.forest)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(2...4)
                .font(Vida.sans(15))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Vida.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Vida.hairline, lineWidth: 0.9) }
        }
    }

    private var emailBody: String {
        AppointmentRequestEmail.body(
            provider: provider,
            preferred: preferred,
            reason: reason,
            visitSummary: includePrep ? prep?.visitSummary : nil,
            patientName: store.name
        )
    }

    private var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = provider.email ?? ""
        components.queryItems = [
            URLQueryItem(name: "subject", value: AppointmentRequestEmail.subject(for: provider)),
            URLQueryItem(name: "body", value: emailBody),
        ]
        return components.url
    }

    private func save() {
        guard let userID = auth.user?.id else {
            failure = "Sign in again to save this request."
            return
        }
        isSaving = true
        failure = nil
        Task {
            do {
                let record = try await AppointmentService.create(
                    .make(userID: userID, provider: provider, preferred: preferred, reason: reason, notes: notes)
                )
                AppointmentService.remember(provider)
                if remind {
                    reminderScheduled = await AppointmentService.scheduleReminder(for: record, at: preferred)
                }
                saved = record
            } catch {
                failure = "This request couldn't be saved. Check your connection and try again."
            }
            isSaving = false
        }
    }
}

// MARK: - Appointments list

struct ConciergeAppointmentsPanel: View {
    let onFindDoctor: () -> Void

    @State private var records: [AppointmentRecord] = []
    @State private var isLoading = true
    @State private var failure: String?
    @State private var calendarFor: AppointmentRecord?
    @State private var cancelling: AppointmentRecord?
    private let content = SiteContentService.shared

    /// Contact details saved when the request was made here, or, for a
    /// request made on the website, the directory entry it points to.
    private func provider(for record: AppointmentRecord) -> CareProvider? {
        if let saved = AppointmentService.savedProviders()[record.doctorID] { return saved }
        return content.specialists.value?
            .first { $0.id == record.doctorID }
            .map(CareProvider.init(directory:))
    }

    private var upcoming: [AppointmentRecord] { records.filter { $0.isUpcoming() } }
    private var past: [AppointmentRecord] { records.filter { !$0.isUpcoming() }.reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if isLoading {
                ProgressView().tint(Vida.moss).frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if let failure {
                Text(failure).font(Vida.sans(14)).foregroundStyle(Vida.clay)
            } else if records.isEmpty {
                VStack(spacing: 14) {
                    QuietEmptyState(symbol: "calendar", title: "No appointments yet", message: "Find a doctor near you and request a visit. It shows up here and on vidalab.co.")
                    Button(action: onFindDoctor) {
                        Text("Find a doctor")
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(Vida.onForest)
                            .padding(.horizontal, 22)
                            .frame(minHeight: 46)
                            .background(Vida.forest, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            } else {
                if !upcoming.isEmpty {
                    SectionHeading(eyebrow: "Coming up", title: "Upcoming")
                    ForEach(upcoming) { row($0) }
                }
                if !past.isEmpty {
                    SectionHeading(eyebrow: "History", title: "Past and cancelled")
                    ForEach(past) { row($0) }
                }
            }
        }
        .task {
            await content.loadSpecialists()
            await load()
        }
        .confirmationDialog(
            "Cancel this request?",
            isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }),
            titleVisibility: .visible,
            presenting: cancelling
        ) { record in
            Button("Cancel request", role: .destructive) { Task { await update(record, .cancelled) } }
            Button("Keep it", role: .cancel) { }
        } message: { record in
            Text("This only updates VIDA LAB. If the office already booked \(record.practiceName ?? record.doctorName), call them to cancel too.")
        }
        .sheet(item: $calendarFor) { record in
            let provider = provider(for: record)
            CalendarEventSheet(
                title: "Appointment: \(record.practiceName ?? record.doctorName)",
                start: record.startDate() ?? .now,
                location: [provider?.addressLine, provider?.cityLine].compactMap { $0 }.joined(separator: ", "),
                notes: record.reason ?? ""
            )
            .ignoresSafeArea()
        }
    }

    private func row(_ record: AppointmentRecord) -> some View {
        let provider = provider(for: record)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.practiceName ?? record.doctorName)
                    .font(Vida.sans(16, weight: .semibold))
                    .foregroundStyle(Vida.forest)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(record.statusValue.label)
                    .font(Vida.sans(11, weight: .semibold))
                    .foregroundStyle(record.statusValue == .confirmed ? Vida.cream : Vida.forest)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(record.statusValue == .confirmed ? Vida.moss : Vida.sage.opacity(0.22), in: Capsule())
            }
            if let start = record.startDate() {
                Text(start.formatted(date: .complete, time: record.appointmentTime.contains(":") ? .shortened : .omitted))
                    .font(Vida.sans(14))
                    .foregroundStyle(Vida.ink)
            }
            if let reason = record.reason, !reason.isEmpty {
                Text(reason).font(Vida.sans(13)).foregroundStyle(Vida.inkSoft).lineLimit(3)
            }
            if record.isUpcoming() {
                HStack(spacing: 8) {
                    if let phone = provider?.phoneURL {
                        ContactLink(title: "Call", symbol: "phone", url: phone, spoken: "Call \(record.practiceName ?? record.doctorName)")
                    }
                    Menu {
                        if record.statusValue == .requested {
                            Button("Mark confirmed", systemImage: "checkmark.circle") { Task { await update(record, .confirmed) } }
                        }
                        Button("Add to Calendar", systemImage: "calendar.badge.plus") { calendarFor = record }
                        Button("Mark done", systemImage: "checkmark.seal") { Task { await update(record, .completed) } }
                        Button("Cancel request", systemImage: "xmark.circle", role: .destructive) { cancelling = record }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                            .font(Vida.sans(13, weight: .semibold))
                            .foregroundStyle(Vida.moss)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Vida.sage.opacity(0.16), in: Capsule())
                    }
                    .accessibilityLabel("More options for \(record.practiceName ?? record.doctorName)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 16)
    }

    private func load() async {
        isLoading = true
        do {
            records = try await AppointmentService.list()
            failure = nil
        } catch {
            failure = "Your appointments couldn't load. Check your connection and try again."
        }
        isLoading = false
    }

    private func update(_ record: AppointmentRecord, _ status: AppointmentRecord.Status) async {
        do {
            try await AppointmentService.setStatus(status, for: record.id)
            await load()
        } catch {
            failure = "That change couldn't be saved. Please try again."
        }
    }
}

// MARK: - System sheets

/// Apple's own add-event screen. On iOS 17 and later it needs no calendar
/// permission: the event is only saved if the member taps Add.
struct CalendarEventSheet: UIViewControllerRepresentable {
    let title: String
    let start: Date
    let location: String
    let notes: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(3600)
        event.location = location.isEmpty ? nil : location
        event.notes = notes.isEmpty ? nil : notes
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

/// Mail's compose screen, sent from the member's own account.
struct MailComposeSheet: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        if !recipient.isEmpty { controller.setToRecipients([recipient]) }
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}
