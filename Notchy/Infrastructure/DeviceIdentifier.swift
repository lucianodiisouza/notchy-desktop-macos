import Foundation
import IOKit

/// Provides a stable hardware identifier for this Mac (IOPlatformUUID).
enum DeviceIdentifier {
    /// Returns the platform UUID string, or a fallback if unavailable.
    static var deviceId: String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        guard service != 0,
              let unmanaged = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0) else {
            return fallbackDeviceId
        }
        let value = unmanaged.takeRetainedValue()
        guard CFGetTypeID(value) == CFStringGetTypeID() else {
            return fallbackDeviceId
        }
        let uuid = (value as! CFString) as String
        return uuid.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
