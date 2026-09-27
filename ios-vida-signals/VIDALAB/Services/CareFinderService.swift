import Foundation
import CoreLocation
import MapKit
import Supabase
import UserNotifications

/// Finds doctors near the member: VIDA LAB's directory first, then Apple Maps.
///
/// Location is read once, only when she taps "Use my location", and never
/// leaves the device except as the area Apple Maps searches.
enum CareFinderService {
    enum LocationProblem: Error {
        case denied
        case unavailable
    }

    /// One current location, or a clear reason there isn't one.
    ///
    /// The timeout is generous because the first request includes the
    /// permission prompt, and someone reading it shouldn't lose the search.
    static func currentLocation(timeout: Duration = .seconds(45)) async throws -> CLLocation {
        try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if let location = update.location { return location }
                    if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                        throw LocationProblem.denied
                    }
                }
                throw LocationProblem.unavailable
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw LocationProblem.unavailable
            }
            let location = try await group.next() ?? CLLocation()
            group.cancelAll()
            return location
        }
    }

    /// The state, city, and ZIP around a location, so the directory can be
    /// matched without geocoding every practice in it.
    static func area(around location: CLLocation) async -> CareArea {
        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return CareArea(label: "Near you")
        }
        return CareArea(
            label: [placemark.locality, placemark.administrativeArea].compactMap { $0 }.joined(separator: ", "),
            state: placemark.administrativeArea?.uppercased(),
            city: placemark.locality,
            zip: placemark.postalCode
        )
    }

    /// Where an address is, cached on the device so each practice is only
    /// looked up once. Used to put real distances on directory results, which
    /// have street addresses but no coordinates.
    static func location(ofAddress address: String, cacheKey: String) async -> CLLocation? {
        let defaults = UserDefaults.standard
        var cache = defaults.dictionary(forKey: geocodeCacheKey) as? [String: [Double]] ?? [:]
        if let pair = cache[cacheKey], pair.count == 2 {
            return CLLocation(latitude: pair[0], longitude: pair[1])
        }
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let found = try? await CLGeocoder().geocodeAddressString(trimmed).first?.location else { return nil }
        cache[cacheKey] = [found.coordinate.latitude, found.coordinate.longitude]
        defaults.set(cache, forKey: geocodeCacheKey)
        return found
    }

    private static let geocodeCacheKey = "vida.care.geocodeCache.v1"

    /// Apple's one-line addresses can carry a double space before the ZIP.
    static func collapseSpaces(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Apple Maps results for a specialty. With a location, searches a ~25 mile
    /// radius around it; with typed text, searches "<specialty> near <text>".
    static func mapsResults(for specialty: CareSpecialty, near location: CLLocation?, typedArea: String) async -> [CareProvider] {
        let request = MKLocalSearch.Request()
        request.resultTypes = .pointOfInterest
        if let location {
            request.naturalLanguageQuery = specialty.mapsQuery
            request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 80_000, longitudinalMeters: 80_000)
        } else {
            request.naturalLanguageQuery = "\(specialty.mapsQuery) near \(typedArea)"
        }

        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.prefix(25).compactMap { item in
            guard let name = item.name else { return nil }
            let coordinate = coordinate(of: item)
            let (street, city) = addressLines(of: item)
            return CareProvider(
                id: "maps:\(name.lowercased())|\(String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude))",
                source: .maps,
                name: name,
                specialty: specialty.title == "Primary care" ? "Primary care" : specialty.title,
                addressLine: street,
                cityLine: city,
                phone: item.phoneNumber,
                email: nil,
                website: item.url?.absoluteString,
                acceptingNewPatients: nil,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    private static func coordinate(of item: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return item.location.coordinate
        }
        return item.placemark.coordinate
    }

    private static func addressLines(of item: MKMapItem) -> (String?, String?) {
        if #available(iOS 26.0, *) {
            // One line that already includes the city; adding the city again
            // printed it twice ("Orlando / Orlando, FL").
            let full = item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
            return ((full ?? item.address?.shortAddress).map(collapseSpaces), nil)
        }
        let placemark = item.placemark
        let street = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        let city = [placemark.locality, placemark.administrativeArea].compactMap { $0 }.joined(separator: ", ")
        return (street.isEmpty ? nil : street, city.isEmpty ? nil : city)
    }
}

/// Appointment requests, stored in the same `appointments` table the website
/// uses, plus the on-device pieces: practice contact details and reminders.
enum AppointmentService {
    static func list() async throws -> [AppointmentRecord] {
        try await vidaSupabase
            .from("appointments")
            .select(AppointmentRecord.selectColumns)
            .order("appointment_date", ascending: true)
            .limit(100)
            .execute()
            .value
    }

    static func create(_ insert: AppointmentInsert) async throws -> AppointmentRecord {
        try await vidaSupabase
            .from("appointments")
            .insert(insert, returning: .representation)
            .select(AppointmentRecord.selectColumns)
            .single()
            .execute()
            .value
    }

    static func setStatus(_ status: AppointmentRecord.Status, for id: String) async throws {
        struct Change: Encodable {
            let status: String
            let updated_date: Date
        }
        try await vidaSupabase
            .from("appointments")
            .update(Change(status: status.rawValue, updated_date: .now))
            .eq("id", value: id)
            .execute()
        if status == .cancelled || status == .completed {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID(id)])
        }
    }

    // MARK: Contact details

    // The table has no phone or address columns, so a practice's details are
    // kept here, keyed by doctor ID, for the Call and Directions buttons.

    private static var contactsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("care-providers.json", isDirectory: false)
    }

    static func remember(_ provider: CareProvider) {
        var all = savedProviders()
        all[provider.id] = provider
        try? FileManager.default.createDirectory(at: contactsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: contactsURL, options: [.atomic, .completeFileProtection])
        }
    }

    static func savedProviders() -> [String: CareProvider] {
        guard let data = try? Data(contentsOf: contactsURL),
              let all = try? JSONDecoder().decode([String: CareProvider].self, from: data) else { return [:] }
        return all
    }

    /// Everything this device keeps about appointments: practice details and
    /// scheduled reminders. Used on account deletion.
    static func clearLocal() async {
        try? FileManager.default.removeItem(at: contactsURL)
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("vida.appointment.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: Reminders

    private static func reminderID(_ appointmentID: String) -> String { "vida.appointment.\(appointmentID)" }

    /// A local reminder the evening before (6 PM), or two hours before when
    /// that's already past. Asks for notification permission if it hasn't
    /// been decided. Returns whether a reminder was scheduled.
    @discardableResult
    static func scheduleReminder(for record: AppointmentRecord, at start: Date) async -> Bool {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return false }

        let calendar = Calendar.current
        let eveningBefore = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: start) ?? start)
        let twoHoursBefore = start.addingTimeInterval(-2 * 3600)
        guard let fireDate = [eveningBefore, twoHoursBefore].compactMap({ $0 }).first(where: { $0 > .now }) else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Appointment coming up"
        content.body = "\(record.practiceName ?? record.doctorName), \(start.formatted(date: .abbreviated, time: .shortened)). Your visit prep is in the Appointment Concierge."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        do {
            try await center.add(UNNotificationRequest(identifier: reminderID(record.id), content: content, trigger: trigger))
            return true
        } catch {
            return false
        }
    }
}
