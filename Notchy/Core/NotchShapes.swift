import SwiftUI

/// Only the bottom edge is rounded so the bar looks docked into the top of the screen.
/// Radius scales with window size so small windows don't lose rounding or clip icons.
struct NotchBarShape: Shape {
    private static let maxCornerRadius: CGFloat = 10
    private static let minCornerRadius: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        let r = effectiveCornerRadius(for: rect)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.maxY))
        path.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.closeSubpath()
        return path
    }

    /// Keeps corner radius proportional to window size so content isn't clipped when small.
    private func effectiveCornerRadius(for rect: CGRect) -> CGFloat {
        let smallSide = min(rect.width, rect.height)
        let proportional = smallSide * 0.06
        let capped = min(Self.maxCornerRadius, max(Self.minCornerRadius, proportional))
        let maxValid = min(rect.width / 2, rect.height)
        return min(capped, max(1, maxValid - 1))
    }
}

/// Two diagonal lines in the corner for resize grip (Mac-style).
struct ResizeGripShape: Shape {
    func path(in rect: CGRect) -> Path {
        let margin: CGFloat = 6
        let spacing: CGFloat = 4
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + margin, y: rect.maxY - margin))
        path.addLine(to: CGPoint(x: rect.maxX - margin, y: rect.minY + margin))
        path.move(to: CGPoint(x: rect.minX + margin + spacing, y: rect.maxY - margin))
        path.addLine(to: CGPoint(x: rect.maxX - margin, y: rect.minY + margin + spacing))
        return path
    }
}
