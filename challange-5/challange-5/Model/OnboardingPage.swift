import Foundation
import UIStringsKit

struct OnboardingPage: Sendable, Identifiable {
    let id: Int
    let titleKey: UIStringKey
    let bodyKey: UIStringKey
    let symbolName: String
}
