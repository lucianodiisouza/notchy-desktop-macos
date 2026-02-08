import Foundation
import IOKit

/// Provides a stable hardware identifier for this Mac (IOPlatformUUID).
/// Used to validate premium status with the backend.
enum DeviceIdentifier {
    /// Returns the platform UUID string, or a fallback if unavailable.
    static var deviceId: String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        guard service != 0,
              let uuid = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0) as? String else {
            return fallbackDeviceId
        }
        return uuid.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fallback when IOKit is unavailable (e.g. sandbox); stable per app install.
    private static var fallbackDeviceId: String {
        let key = "NotchyDeviceIdFallback"
        let suite = UserDefaults(suiteName: NotchyKeys.appGroupIdentifier)
        if let existing = suite?.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        suite?.set(newId, forKey: key)
        return newId
    }
}
