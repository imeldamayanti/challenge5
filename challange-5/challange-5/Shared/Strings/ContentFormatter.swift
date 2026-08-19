import ContentKit
import Foundation
import UIStringsKit

/// `NFR-I18N-05` — distances in metric, times in the device's 12/24-hour convention.
///
/// Formatting follows the *app's* language, not the device's locale, because the two can differ by
/// design (`FR-ONB-05`): an Indonesian interface on a US-locale phone must still read "2,6 km".
struct ContentFormatter: Sendable {

    let language: ContentLanguage
    let locale: Locale

    init(language: ContentLanguage) {
        self.language = language
        self.locale = Locale(identifier: language == .id ? "id_ID" : "en_US")
    }

    private func string(_ key: UIStringKey) -> String {
        UIStrings.string(key, language)
    }

    /// Metres under a kilometre, kilometres above it to one decimal. A walker does not need
    /// "2600 m" and cannot use "2.6 km" rendered with the wrong decimal separator.
    func distance(metres: Int) -> String {
        if metres < 1000 {
            return "\(metres) \(string(.unitMetres))"
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let value = formatter.string(from: NSNumber(value: Double(metres) / 1000)) ?? "\(metres / 1000)"
        return "\(value) \(string(.unitKilometres))"
    }

    func duration(minutes: Int) -> String {
        "\(minutes) \(string(.unitMinutes))"
    }

    /// Zero is rendered as "Free" rather than as a formatted zero — `FR-DISC-05` is about a user
    /// not being surprised by a cost, and "Rp 0" makes them look twice.
    func cost(amount: Int, currency: String) -> String {
        guard amount > 0 else { return string(.costFree) }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        // IDR has no minor unit in practice; showing "Rp 50.000,00" is noise.
        formatter.maximumFractionDigits = currency == "IDR" ? 0 : 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currency)"
    }

    /// Wall-clock times in the device's own 12/24-hour convention (`NFR-I18N-05`). Content authors
    /// write `"15:30"`; whether the user reads that or "3:30 PM" is their system setting's
    /// business, so this formatter uses the *device* locale rather than the app-language locale —
    /// unlike distances, where the decimal separator should follow the language being read.
    func time(_ time: TimeOfDay, calendar: Calendar = .current) -> String {
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        guard let date = calendar.date(from: components) else { return time.text }

        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.calendar = calendar
        return formatter.string(from: date)
    }

    func window(_ window: StartWindow, calendar: Calendar = .current) -> String {
        "\(time(window.from, calendar: calendar))–\(time(window.to, calendar: calendar))"
    }

    /// Named checkpoints, not quests — see `QuestListRow.checkpointCount`.
    func checkpointCount(_ count: Int) -> String {
        "\(count) \(string(count == 1 ? .unitCheckpointSingular : .unitCheckpointPlural))"
    }

    func bytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        // Without this, zero renders as "Zero KB", which reads as a bug rather than as a number.
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(count))
    }

    func photoPolicy(_ level: PhotoPolicyLevel) -> String {
        switch level {
        case .allowed: string(.photoPolicyAllowed)
        case .restricted: string(.photoPolicyRestricted)
        case .prohibited: string(.photoPolicyProhibited)
        }
    }

    func accuracyLabel(_ accuracy: AccuracyLabel) -> String {
        switch accuracy {
        case .documented: string(.accuracyDocumented)
        case .oral: string(.accuracyOral)
        }
    }
}
