import Foundation
import Combine

/// Notchy is free. This service exists only for API compatibility; it always reports full access and no ban.
final class PremiumService: ObservableObject {
    static let shared = PremiumService()

    @Published private(set) var isPremium: Bool = true
    @Published private(set) var isBanned: Bool = false

    private init() {}

    /// No-op; kept for call sites that invoke start on launch.
    func start() {}

    /// No-op; kept for call sites that trigger a refresh.
    func checkPremium() {}
}
