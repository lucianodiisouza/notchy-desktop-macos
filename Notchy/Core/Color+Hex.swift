import SwiftUI
import AppKit

/// Hex string (e.g. "FFFFFF" or "AARRGGBB") to SwiftUI Color. Used for text and buttons.
func colorFromHex(_ hex: String) -> Color {
    let (r, g, b, a) = componentsFromHex(hex)
    return Color(red: r, green: g, blue: b, opacity: a > 0 ? a : 1)
}

/// Same as colorFromHex but ignores alpha (for button/icon tint). Default opacity applied by callers.
func buttonColorFromHex(_ hex: String) -> Color {
    let (r, g, b, _) = componentsFromHex(hex)
    return Color(red: r, green: g, blue: b)
}

/// SwiftUI Color to hex string "RRGGBB" (no alpha).
func hexFromColor(_ color: Color) -> String {
    let ns = NSColor(color)
    let r = Int((ns.redComponent * 255).rounded())
    let g = Int((ns.greenComponent * 255).rounded())
    let b = Int((ns.blueComponent * 255).rounded())
    return String(format: "%02X%02X%02X", r, g, b)
}

private func componentsFromHex(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double) {
    let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: s).scanHexInt64(&int)
    let a = Double((int >> 24) & 0xFF) / 255
    let r = Double((int >> 16) & 0xFF) / 255
    let g = Double((int >> 8) & 0xFF) / 255
    let b = Double(int & 0xFF) / 255
    return (r, g, b, a)
}
