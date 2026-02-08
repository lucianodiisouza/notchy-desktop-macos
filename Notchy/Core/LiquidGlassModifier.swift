import SwiftUI

// MARK: - Liquid Glass background (with fallback)

/// Applies a liquid glass–style background: native liquid glass on macOS 26+ (Tahoe),
/// and a material fallback on earlier versions. Use behind TabView, NavigationSplitView, or Form content.
///
/// To enable native liquid glass when building with Xcode 26+ (macOS 26 SDK), replace the single
/// `background(.regularMaterial)` below with:
/// ```swift
/// if #available(macOS 26.0, *) {
///     self.background { Color.clear.glassEffect(.regular, in: .rect) }
/// } else {
///     self.background(.regularMaterial)
/// }
/// ```
extension View {

    /// Background that uses liquid glass on macOS 26+ and `.regularMaterial` otherwise.
    func liquidGlassBackground() -> some View {
        background(.regularMaterial)
    }
}
