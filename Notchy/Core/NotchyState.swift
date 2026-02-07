import SwiftUI

/// Shared state for the app so the notch window and menu commands use the same instances.
final class NotchyState: ObservableObject {
    static let shared = NotchyState()

    let windowController = FloatingWindowController()
    let audioMonitor = AudioMonitor()
    let scrollController = ScrollController()

    private init() {}
}
