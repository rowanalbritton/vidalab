import CoreLocation
import Foundation
import Testing
@testable import VIDALAB

struct ConciergeCareTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func practice(_ id: String, _ name: String, specialty: String, category: String, city: String, state: String, zip: String) throws -> SpecialistPractice {
        let json = """
        {"id":"\(id)","practice_name":"\(name)","specialty":"\(specialty)","category":"\(category)",
         "phone":"(407) 555-0100","email":"hello@example.com","address":"1 Main St","city":"\(city)",
         "state":"\(state)","zip_code":"\(zip)","website":"example.com","accepting_new_patients":true,"notes":null}
        """
        return try JSONDecoder().decode(SpecialistPractice.self, from: Data(json.utf8))
    }

    // MARK: Areas

    @Test func areasParseCityStateAndZip() {
        let cityState = CareArea.parse("Orlando, FL")
        #expect(cityState.city == "Orlando")
        #expect(cityState.state == "FL")

        let zip = CareArea.parse("32801")
        #expect(zip.zip == "32801")
        #expect(zip.city == nil)

        let full = CareArea.parse("Boston, MA 02115")
        #expect(full.state == "MA")
        #expect(full.zip == "02115")

        let loose = CareArea.parse("Brooklyn")
        #expect(loose.city == "Brooklyn")
        #expect(loose.state == nil)
    }

    // MARK: Directory matching

    @Test func directoryMatchesSpecialtyAndPrefersTheClosestArea() throws {
        let practices = [
            try practice("1", "Tampa Rheumatology", specialty: "Rheumatologist", category: "autoimmune", city: "Tampa", state: "FL", zip: "33602"),
            try practice("2", "Orlando Rheumatology", specialty: "Rheumatologist", category: "autoimmune", city: "Orlando", state: "FL", zip: "32801"),
            try practice("3", "Orlando Neurology", specialty: "Neurologist", category: "neurological", city: "Orlando", state: "FL", zip: "32803"),
            try practice("4", "Boston Rheumatology", specialty: "Rheumatologist", category: "autoimmune", city: "Boston", state: "MA", zip: "02115"),
        ]
        let rheum = CareSpecialty.common.first { $0.title == "Rheumatologist" }!

        let matches = CareMatcher.directoryMatches(practices, specialty: rheum, area: CareArea.parse("Orlando, FL 32801"))

        #expect(matches.map(\.id) == ["2", "1"])
    }

    @Test func noAreaMeansAnywhere() throws {
        let practices = [
            try practice("1", "A", specialty: "Gynecologist — Endometriosis Specialist", category: "gynecological", city: "Miami", state: "FL", zip: "33101"),
            try practice("2", "B", specialty: "Neurologist", category: "neurological", city: "Miami", state: "FL", zip: "33101"),
        ]
        let gyn = CareSpecialty.common.first { $0.title == "Gynecologist" }!

        #expect(CareMatcher.directoryMatches(practices, specialty: gyn, area: CareArea(label: "")).map(\.id) == ["1"])
    }

    @Test func specialtiesFromThePrepMapToKnownOnes() {
        #expect(CareSpecialty.matching("Rheumatologist").title == "Rheumatologist")
        #expect(CareSpecialty.matching("A headache specialist").title == "Neurologist")
        #expect(CareSpecialty.matching("Endometriosis excision surgeon").title == "Gynecologist")

        let unusual = CareSpecialty.matching("Allergist")
        #expect(unusual.title == "Allergist")
        #expect(unusual.mapsQuery == "Allergist")
    }

    // MARK: Distance

    private func placedProvider(_ id: String, lat: Double, lon: Double) -> CareProvider {
        CareProvider(id: id, source: .directory, name: id, specialty: nil, addressLine: nil, cityLine: nil,
                     phone: nil, email: nil, website: nil, acceptingNewPatients: nil, latitude: lat, longitude: lon)
    }

    @Test func nearestKeepsCloseProvidersNearestFirst() {
        let orlando = CLLocation(latitude: 28.5383, longitude: -81.3792)
        let providers = [
            placedProvider("gainesville", lat: 29.6516, lon: -82.3248),   // ~100 mi
            placedProvider("winter-park", lat: 28.6000, lon: -81.3392),   // ~5 mi
            placedProvider("kissimmee", lat: 28.2920, lon: -81.4076),     // ~17 mi
        ]

        let result = CareMatcher.nearest(providers, to: orlando)

        #expect(result.providers.map(\.id) == ["winter-park", "kissimmee"])
        #expect(!result.areFar)
    }

    @Test func whenNothingIsCloseTheNearestFewAreFlaggedAsFar() {
        let boston = CLLocation(latitude: 42.3601, longitude: -71.0589)
        let providers = [
            placedProvider("miami", lat: 25.7617, lon: -80.1918),
            placedProvider("nyc", lat: 40.7128, lon: -74.0060),
            placedProvider("chicago", lat: 41.8781, lon: -87.6298),
            placedProvider("orlando", lat: 28.5383, lon: -81.3792),
        ]

        let result = CareMatcher.nearest(providers, to: boston)

        #expect(result.areFar)
        #expect(result.providers.map(\.id) == ["nyc", "chicago", "orlando"])
    }

    // MARK: Appointments

    @Test func aSavedRequestUsesTheWebsitesDateAndTimeFormat() throws {
        let provider = CareProvider(directory: try practice("7", "Orlando Rheumatology", specialty: "Rheumatologist", category: "autoimmune", city: "Orlando", state: "FL", zip: "32801"))
        let preferred = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 14, minute: 30))!

        let insert = AppointmentInsert.make(userID: "u1", provider: provider, preferred: preferred, reason: "  joint pain  ", notes: "", calendar: calendar)

        #expect(insert.appointmentDate == "2026-10-15")
        #expect(insert.appointmentTime == "2:30 PM")
        #expect(insert.reason == "joint pain")
        #expect(insert.status == "requested")
        #expect(insert.doctorID == "7")
    }

    @Test func midnightAndNoonFormatCorrectly() {
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 0, minute: 5))!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12, minute: 0))!

        #expect(AppointmentInsert.timeString(midnight, calendar: calendar) == "12:05 AM")
        #expect(AppointmentInsert.timeString(noon, calendar: calendar) == "12:00 PM")
    }

    private func record(date: String, time: String, status: String) throws -> AppointmentRecord {
        let json = """
        {"id":"a","doctor_id":"7","doctor_name":"X","practice_name":"X","specialty":null,
         "appointment_date":"\(date)","appointment_time":"\(time)","reason":null,"notes":null,"status":"\(status)"}
        """
        return try JSONDecoder().decode(AppointmentRecord.self, from: Data(json.utf8))
    }

    @Test func recordsReadBothClockTimesAndLooserPreferences() throws {
        let exact = try record(date: "2026-10-15", time: "2:30 PM", status: "requested")
        let loose = try record(date: "2026-10-15", time: "Morning", status: "requested")

        let exactStart = try #require(exact.startDate(calendar: calendar))
        let parts = calendar.dateComponents([.hour, .minute], from: exactStart)
        #expect(parts.hour == 14)
        #expect(parts.minute == 30)
        #expect(loose.startDate(calendar: calendar) != nil)
    }

    @Test func upcomingExcludesPastAndCancelled() throws {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!

        #expect(try record(date: "2026-10-15", time: "9:00 AM", status: "requested").isUpcoming(now: now, calendar: calendar))
        #expect(try record(date: "2026-10-01", time: "8:00 AM", status: "confirmed").isUpcoming(now: now, calendar: calendar))
        #expect(!(try record(date: "2026-09-20", time: "9:00 AM", status: "requested").isUpcoming(now: now, calendar: calendar)))
        #expect(!(try record(date: "2026-10-15", time: "9:00 AM", status: "cancelled").isUpcoming(now: now, calendar: calendar)))
    }

    // MARK: Contact and email

    @Test func appleAddressesLoseTheirDoubleSpaces() {
        #expect(CareFinderService.collapseSpaces("1705 Kuhl Ave, #101, Orlando, FL  32806") == "1705 Kuhl Ave, #101, Orlando, FL 32806")
    }

    @Test func providerLinksAreBuiltSafely() {
        let provider = CareProvider(
            id: "maps:x", source: .maps, name: "Clinic", specialty: nil, addressLine: nil, cityLine: nil,
            phone: "+1 (212) 555-0101", email: nil, website: "clinic.example", acceptingNewPatients: nil,
            latitude: 40.7, longitude: -74.0
        )
        #expect(provider.phoneURL?.absoluteString == "tel:+12125550101")
        #expect(provider.websiteURL?.absoluteString == "https://clinic.example")
        #expect(provider.mapsURL?.absoluteString.contains("ll=40.7,-74.0") == true)
    }

    @Test func theRequestEmailReadsCleanly() throws {
        let provider = CareProvider(directory: try practice("7", "Orlando Rheumatology", specialty: "Rheumatologist", category: "autoimmune", city: "Orlando", state: "FL", zip: "32801"))
        let body = AppointmentRequestEmail.body(
            provider: provider,
            preferred: .now,
            reason: "Joint pain and fatigue",
            visitSummary: "Morning stiffness most days.",
            patientName: "Rowan"
        )

        #expect(body.contains("Hello Orlando Rheumatology"))
        #expect(body.contains("Reason for the visit: Joint pain and fatigue"))
        #expect(body.contains("Morning stiffness most days."))
        #expect(body.hasSuffix("Rowan"))
        #expect(!body.contains("\u{2014}"))
    }

    @Test func aConciergeResultWithSpecialistsDecodes() throws {
        let json = """
        {"status":"ok","result":{"visit_summary":"s","symptom_narrative":"n","key_metrics":[],"questions_to_ask":[],
          "tests_to_request":[],"advocacy_script":"a","what_to_bring":[],"specialists_to_see":["Rheumatologist"],"disclaimer":"d"}}
        """
        guard case .ready(.concierge(let result), _) = try VidaPlusInsightsService.outcome(from: Data(json.utf8), feature: .concierge) else {
            Issue.record("Expected a concierge prep")
            return
        }
        #expect(result.specialistsToSee == ["Rheumatologist"])
    }
}
