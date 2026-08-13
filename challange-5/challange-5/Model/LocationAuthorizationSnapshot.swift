import Foundation

/// What Settings may know about location: the current authorisation, and nothing else.
///
/// `FR-ONB-04` requires the permission prompt to appear in context at the first quest-start
/// attempt, with its own explanation screen — never from a Settings row. The protocol therefore has
/// no request method, so Settings cannot ask even by accident.
enum LocationAuthorizationSnapshot: String, Sendable, CaseIterable {
    case notRequested
    case denied
    case whenInUse
    case always
    case restricted
}
