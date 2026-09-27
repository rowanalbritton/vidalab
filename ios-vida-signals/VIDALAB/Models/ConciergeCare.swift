import Foundation
import CoreLocation

// The finding-and-booking half of the Appointment Concierge, matching the
// website's Doctor Finder: search for a specialist near you, then request an
// appointment and keep track of it.
//
// Two sources of doctors, shown together:
//   - VIDA LAB's curated directory (`doctors`), the same list the website uses.
//   - Apple Maps, searched on the device for anything nearby the directory
//     doesn't cover. Nothing about the search is sent to VIDA LAB.

/// A doctor or practice from either source.
nonisolated struct CareProvider: Identifiable, Hashable, Codable, Sendable {
    enum Source: String, Codable, Sendable {
        case directory
        case maps
    }

    let id: String
    let source: Source
    let name: String
    let specialty: String?
    let addressLine: String?
    let cityLine: String?
    let phone: String?
    let email: String?
    let website: String?
    let acceptingNewPatients: Bool?
    let latitude: Double?
    let longitude: Double?

    var phoneURL: URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.count >= 7 ? URL(string: "tel:\(digits)") : nil
    }

    var websiteURL: URL? {
        guard let website, !website.isEmpty else { return nil }
        return URL(string: website.hasPrefix("http") ? website : "https://\(website)")
    }

    var mapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        if let latitude, let longitude {
            components?.queryItems = [
                URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
                URLQueryItem(name: "q", value: name),
            ]
        } else {
            let query = [name, addressLine, cityLine].compactMap { $0 }.joined(separator: ", ")
            components?.queryItems = [URLQueryItem(name: "q", value: query)]
        }
        return components?.url
    }

    /// Google Maps directions. Google's map links open the Google Maps app when
    /// it's installed and google.com/maps otherwise, with no API key.
    var googleDirectionsURL: URL? {
        GoogleMapsLink.directions(to: [name, addressLine, cityLine].compactMap { $0 }.joined(separator: ", "))
    }

    /// The same provider with a known position.
    func placed(at location: CLLocation) -> CareProvider {
        CareProvider(
            id: id, source: source, name: name, specialty: specialty, addressLine: addressLine, cityLine: cityLine,
            phone: phone, email: email, website: website, acceptingNewPatients: acceptingNewPatients,
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude
        )
    }

    /// Miles from `location`, when both ends are known.
    func miles(from location: CLLocation?) -> Double? {
        guard let location, let latitude, let longitude else { return nil }
        return location.distance(from: CLLocation(latitude: latitude, longitude: longitude)) / 1609.344
    }

    init(
        id: String, source: Source, name: String, specialty: String?, addressLine: String?, cityLine: String?,
        phone: String?, email: String?, website: String?, acceptingNewPatients: Bool?,
        latitude: Double? = nil, longitude: Double? = nil
    ) {
        self.id = id
        self.source = source
        self.name = name
        self.specialty = specialty
        self.addressLine = addressLine
        self.cityLine = cityLine
        self.phone = phone
        self.email = email
        self.website = website
        self.acceptingNewPatients = acceptingNewPatients
        self.latitude = latitude
        self.longitude = longitude
    }

    init(directory practice: SpecialistPractice) {
        self.init(
            id: practice.id,
            source: .directory,
            name: practice.practiceName,
            specialty: practice.specialty,
            addressLine: practice.address,
            cityLine: practice.cityLine.isEmpty ? nil : practice.cityLine,
            phone: practice.phone,
            email: practice.email,
            website: practice.website,
            acceptingNewPatients: practice.acceptingNewPatients
        )
    }
}

/// The kinds of specialist people most often need to find. `keywords` match
/// the directory's specialty and category text; `mapsQuery` is what Apple
/// Maps is asked for.
nonisolated struct CareSpecialty: Identifiable, Hashable, Sendable {
    let title: String
    let mapsQuery: String
    let keywords: [String]

    var id: String { title }

    static let common: [CareSpecialty] = [
        .init(title: "Primary care", mapsQuery: "primary care doctor", keywords: ["primary care", "family medicine", "internal medicine"]),
        .init(title: "Gynecologist", mapsQuery: "gynecologist", keywords: ["gyn", "gynecolog", "endometriosis", "pelvic", "menopause"]),
        .init(title: "Endocrinologist", mapsQuery: "endocrinologist", keywords: ["endocrin", "thyroid", "pcos", "diabetes"]),
        .init(title: "Rheumatologist", mapsQuery: "rheumatologist", keywords: ["rheumat", "autoimmune", "lupus"]),
        .init(title: "Neurologist", mapsQuery: "neurologist", keywords: ["neurolog", "headache", "migraine", "multiple sclerosis"]),
        .init(title: "Gastroenterologist", mapsQuery: "gastroenterologist", keywords: ["gastro", "ibd", "crohn", "sibo"]),
        .init(title: "Cardiologist", mapsQuery: "cardiologist", keywords: ["cardio", "heart", "dysautonomia", "pots"]),
        .init(title: "Pain specialist", mapsQuery: "pain management doctor", keywords: ["pain"]),
        .init(title: "Mental health", mapsQuery: "psychiatrist", keywords: ["psychiat", "mental", "therap", "pmdd"]),
        .init(title: "Sleep medicine", mapsQuery: "sleep medicine doctor", keywords: ["sleep"]),
    ]

    /// A specialty from free text, such as one the visit prep suggested.
    static func matching(_ text: String) -> CareSpecialty {
        let lowered = text.lowercased()
        if let known = common.first(where: { specialty in
            lowered.contains(specialty.title.lowercased()) || specialty.keywords.contains { lowered.contains($0) }
        }) {
            return known
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count > 3 }
        return CareSpecialty(title: trimmed, mapsQuery: trimmed, keywords: words.isEmpty ? [lowered] : words)
    }
}

/// Where to look: the member's own location, or a place she typed.
nonisolated struct CareArea: Hashable, Sendable {
    var label: String
    /// Two-letter state, when known.
    var state: String?
    var city: String?
    var zip: String?

    /// Reads "Orlando, FL", "32801", or "FL" without a network call. Anything
    /// it can't parse still works as free text for Apple Maps.
    static func parse(_ text: String) -> CareArea {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var area = CareArea(label: trimmed)
        if let zip = trimmed.firstMatch(of: /\b(\d{5})\b/) {
            area.zip = String(zip.1)
        }
        let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts.reversed() {
            let letters = part.split(separator: " ").first.map(String.init) ?? part
            if letters.count == 2, letters.allSatisfy(\.isLetter), usStates.contains(letters.uppercased()) {
                area.state = letters.uppercased()
                break
            }
        }
        if parts.count >= 2 {
            area.city = parts[0]
        } else if area.zip == nil, area.state == nil, !trimmed.isEmpty {
            area.city = trimmed
        }
        return area
    }

    static let usStates: Set<String> = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS",
        "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC",
        "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
    ]
}

nonisolated enum CareMatcher {
    /// Directory practices for a specialty in or near an area, closest match
    /// first: same ZIP prefix, then same city, then same state.
    static func directoryMatches(_ practices: [SpecialistPractice], specialty: CareSpecialty, area: CareArea) -> [SpecialistPractice] {
        let keywords = specialty.keywords.map { $0.lowercased() }
        let ranked: [(SpecialistPractice, Int)] = practices.compactMap { practice in
            let text = [practice.specialty, practice.category, practice.notes, practice.practiceName]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
                .replacingOccurrences(of: "_", with: " ")
            guard keywords.contains(where: { text.contains($0) }) else { return nil }

            var score = 0
            if let zip = area.zip, let practiceZip = practice.zipCode, practiceZip.prefix(3) == zip.prefix(3) { score += 4 }
            if let city = area.city?.lowercased(), let practiceCity = practice.city?.lowercased(), practiceCity == city { score += 2 }
            if let state = area.state, practice.state?.uppercased() == state { score += 1 }
            // No area at all means "anywhere"; otherwise require some overlap.
            let hasArea = area.zip != nil || area.city != nil || area.state != nil
            guard !hasArea || score > 0 else { return nil }
            return (practice, score)
        }
        return ranked
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.practiceName < $1.0.practiceName }
            .map(\.0)
    }

    /// Providers within `miles` of a point, nearest first. When none are that
    /// close, the nearest `fallback` instead, flagged so the screen can say
    /// they're farther away rather than pass them off as nearby.
    static func nearest(_ providers: [CareProvider], to reference: CLLocation, within miles: Double = 75, fallback: Int = 3) -> (providers: [CareProvider], areFar: Bool) {
        let sorted = providers.sorted { ($0.miles(from: reference) ?? .infinity) < ($1.miles(from: reference) ?? .infinity) }
        let close = sorted.filter { ($0.miles(from: reference) ?? .infinity) <= miles }
        if !close.isEmpty { return (close, false) }
        return (Array(sorted.filter { $0.miles(from: reference) != nil }.prefix(fallback)), true)
    }
}

/// Links into Google Maps (app or web), built from Google's public Maps URLs.
nonisolated enum GoogleMapsLink {
    static func directions(to destination: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/maps/dir/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: destination),
        ]
        return components?.url
    }

    static func search(_ query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/maps/search/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: query),
        ]
        return components?.url
    }

    /// "rheumatologist near Orlando, FL", or near coordinates when she used
    /// her location.
    static func search(specialty: String, near place: String?, latitude: Double?, longitude: Double?) -> URL? {
        if let latitude, let longitude {
            return search("\(specialty) near \(String(format: "%.4f,%.4f", latitude, longitude))")
        }
        if let place, !place.trimmingCharacters(in: .whitespaces).isEmpty {
            return search("\(specialty) near \(place)")
        }
        return search("\(specialty) near me")
    }
}

// MARK: - Appointments

/// A row in the `appointments` table, the same one the website's Doctor
/// Finder writes, so a request made in either place shows up in both.
nonisolated struct AppointmentRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let doctorID: String
    let doctorName: String
    let practiceName: String?
    let specialty: String?
    /// YYYY-MM-DD
    let appointmentDate: String
    /// "9:30 AM", or a looser preference the website allows, like "Morning".
    let appointmentTime: String
    let reason: String?
    let notes: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, specialty, reason, notes, status
        case doctorID = "doctor_id"
        case doctorName = "doctor_name"
        case practiceName = "practice_name"
        case appointmentDate = "appointment_date"
        case appointmentTime = "appointment_time"
    }

    static let selectColumns = "id,doctor_id,doctor_name,practice_name,specialty,appointment_date,appointment_time,reason,notes,status"

    enum Status: String, CaseIterable, Sendable {
        case requested, confirmed, cancelled, completed

        var label: String {
            switch self {
            case .requested: "Requested"
            case .confirmed: "Confirmed"
            case .cancelled: "Cancelled"
            case .completed: "Done"
            }
        }
    }

    var statusValue: Status { Status(rawValue: status) ?? .requested }

    /// The appointment as a date, when the time was saved as a clock time.
    func startDate(calendar: Calendar = .current) -> Date? {
        let parts = appointmentDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 9)
        if let match = appointmentTime.firstMatch(of: /^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$/) {
            var hour = Int(match.1) ?? 9
            let isPM = match.3.lowercased() == "pm"
            if isPM, hour < 12 { hour += 12 }
            if !isPM, hour == 12 { hour = 0 }
            components.hour = hour
            components.minute = Int(match.2) ?? 0
        }
        return calendar.date(from: components)
    }

    /// Still ahead and not cancelled.
    func isUpcoming(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard statusValue == .requested || statusValue == .confirmed else { return false }
        guard let start = startDate(calendar: calendar) else { return true }
        return calendar.startOfDay(for: start) >= calendar.startOfDay(for: now)
    }
}

/// What the app writes when a member saves a request.
nonisolated struct AppointmentInsert: Encodable, Sendable {
    let userID: String
    let doctorID: String
    let doctorName: String
    let practiceName: String
    let specialty: String
    let appointmentDate: String
    let appointmentTime: String
    let reason: String
    let notes: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case specialty, reason, notes, status
        case userID = "user_id"
        case doctorID = "doctor_id"
        case doctorName = "doctor_name"
        case practiceName = "practice_name"
        case appointmentDate = "appointment_date"
        case appointmentTime = "appointment_time"
    }

    static func make(userID: String, provider: CareProvider, preferred: Date, reason: String, notes: String, calendar: Calendar = .current) -> AppointmentInsert {
        AppointmentInsert(
            userID: userID,
            doctorID: provider.id,
            doctorName: provider.name,
            practiceName: provider.name,
            specialty: provider.specialty ?? "",
            appointmentDate: InsightRequest.dayString(preferred, calendar: calendar),
            appointmentTime: timeString(preferred, calendar: calendar),
            reason: String(reason.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)),
            notes: String(notes.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000)),
            status: AppointmentRecord.Status.requested.rawValue
        )
    }

    /// "9:30 AM", in a fixed format so the website and app read it the same.
    static func timeString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 9
        let minute = parts.minute ?? 0
        let display = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", display, minute, hour < 12 ? "AM" : "PM")
    }
}

/// The email a member can send the practice from her own Mail app.
nonisolated enum AppointmentRequestEmail {
    static func subject(for provider: CareProvider) -> String {
        "Appointment request for a new patient"
    }

    static func body(provider: CareProvider, preferred: Date, reason: String, visitSummary: String?, patientName: String) -> String {
        let when = preferred.formatted(date: .complete, time: .shortened)
        var lines = [
            "Hello \(provider.name),",
            "",
            "I'd like to request an appointment\(provider.specialty.map { " with a \($0.lowercased())" } ?? "").",
            "",
            "Preferred time: \(when), or the nearest available.",
        ]
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedReason.isEmpty { lines.append("Reason for the visit: \(trimmedReason)") }
        if let visitSummary, !visitSummary.isEmpty {
            lines += ["", "A short summary I prepared from my own symptom tracking:", visitSummary]
        }
        lines += [
            "",
            "Please let me know what times you have and whether you're accepting new patients.",
            "",
            "Thank you,",
            patientName.isEmpty ? "" : patientName,
        ]
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
