import Foundation
import Combine

/// Validates premium status with the backend (on launch and every hour).
/// Writes result to App Group so both Notchy and Notchy Scripts use the same value.
/// Notchy (Prompter) uses `isPremium` to apply 2% opacity when inactive; Notchy Scripts stays fully usable when not banned. When banned, both apps are blocked.
/// When the account is banned, `isBanned` is true and the app is blocked until the admin unbans the device.
final class PremiumService: ObservableObject {
    static let shared = PremiumService()

    /// Current premium status; defaults to false until first successful check.
    @Published private(set) var isPremium: Bool = false
    /// True when the backend returned banned: true; app usage is blocked until unbanned.
    @Published private(set) var isBanned: Bool = false

    private var hourlyTimer: Timer?
    private let queue = DispatchQueue(label: "com.notchy.premium", qos: .utility)

    private init() {
        loadFromAppGroup()
    }

    /// Call on app launch (both Notchy and Notchy Scripts). Performs immediate check and schedules hourly.
    func start() {
        queue.async { [weak self] in
            self?.checkPremium()
        }
        scheduleHourly()
    }

    private func scheduleHourly() {
        DispatchQueue.main.async { [weak self] in
            self?.hourlyTimer?.invalidate()
            let timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
                self?.queue.async {
                    self?.checkPremium()
                }
            }
            timer.tolerance = 60
            self?.hourlyTimer = timer
        }
    }

    private var appGroupSuite: UserDefaults? {
        UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)
    }

    private func loadFromAppGroup() {
        let premium = appGroupSuite?.bool(forKey: NotchyKeys.premiumActive) ?? false
        let banned = appGroupSuite?.bool(forKey: NotchyKeys.accountBanned) ?? false
        DispatchQueue.main.async { [weak self] in
            self?.isPremium = premium
            self?.isBanned = banned
        }
    }

    private func saveToAppGroup(premium: Bool, banned: Bool = false) {
        appGroupSuite?.set(premium, forKey: NotchyKeys.premiumActive)
        appGroupSuite?.set(banned, forKey: NotchyKeys.accountBanned)
        DispatchQueue.main.async { [weak self] in
            self?.isPremium = premium
            self?.isBanned = banned
        }
    }

    /// Performs a single check; called on launch and hourly. Sends user email when set (for support/identification).
    func checkPremium() {
        let deviceId = DeviceIdentifier.deviceId
        let baseURL = NotchyKeys.premiumCheckBaseURL
        let userEmail = (UserDefaults.standard.string(forKey: NotchyKeys.userEmail) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var path = "\(baseURL)/api/check?deviceId=\(deviceId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deviceId)"
        if !userEmail.isEmpty, let encoded = userEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "&email=\(encoded)"
        }
        guard let url = URL(string: path) else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let premium = json["premium"] as? Bool else {
                return
            }
            let banned = (json["banned"] as? Bool) ?? false
            self?.saveToAppGroup(premium: banned ? false : premium, banned: banned)
        }
        task.resume()
    }
}
