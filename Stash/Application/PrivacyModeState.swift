import Foundation
import Combine

@MainActor
final class PrivacyModeState: ObservableObject {
    @Published var isPaused: Bool = false
}
