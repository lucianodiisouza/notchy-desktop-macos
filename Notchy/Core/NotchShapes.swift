import SwiftUI

/// Bottom edge is always rounded (docked into the top of the screen).
/// When collapsed, top edge is flat (no radius); only the bottom corners are rounded.
struct NotchBarShape: Shape {
    /// When true (collapsed), top edge is straight; only bottom corners use radius.
    var roundTopCorners: Bool = false
    /// When set (collapsed + notch), a rounded rect is cut out at the top center so the bar doesn't cover the camera.
    var notchCutoutWidth: CGFloat?
    var notchCutoutHeight: CGFloat?

    private static let maxCornerRadius: CGFloat = 10
    private static let minCornerRadius: CGFloat = 4
    private static let collapsedBottomCornerRadius: CGFloat = 8
    /// On non-notch displays (no cutout), collapsed bar uses this radius so it stays rounded-rectangle, not pill-shaped.
    private static let collapsedNoNotchCornerRadius: CGFloat = 10
    /// Raio mínimo dos cantos inferiores quando recolhido, para não ficarem “quadrados” na faixa do notch.
    func path(in rect: CGRect) -> Path {
        let hasNotchCutout = (notchCutoutWidth ?? 0) > 0 && (notchCutoutHeight ?? 0) > 0
        var r = effectiveCornerRadius(for: rect)
        if roundTopCorners {
            if hasNotchCutout {
                let maxRByHeight = max(1, rect.height / 2 - 1)
                r = min(maxRByHeight, rect.width / 2 - 1)
                r = max(r, min(Self.collapsedBottomCornerRadius, rect.height - 1, rect.width / 2 - 1))
            } else {
                // No notch: keep rounded-rectangle corners (squared with rounded corners), not pill-shaped.
                r = min(r, Self.collapsedNoNotchCornerRadius)
                r = min(r, rect.width / 2 - 1, rect.height - 1)
            }
        }
        var path = Path()
        if roundTopCorners {
            // Recolhido: topo reto (sem radius), só os cantos de baixo arredondados.
            if let cw = notchCutoutWidth, let ch = notchCutoutHeight, cw > 0, ch > 0 {
                path = pathCollapsedBarWithNotchCutout(rect: rect, r: r, cutoutWidth: cw, cutoutHeight: ch)
            } else {
                // Topo reto, base com cantos arredondados
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: rect.maxX, y: 0))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
                path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
                path.addLine(to: CGPoint(x: r, y: rect.maxY))
                path.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.closeSubpath()
            }
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
            path.addLine(to: CGPoint(x: r, y: rect.maxY))
            path.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
            path.closeSubpath()
        }
        return path
    }

    /// Barra recolhida com contorno fechado (topo reto, base com cantos arredondados).
    private func pathCollapsedBarWithNotchCutout(rect: CGRect, r: CGFloat, cutoutWidth cw: CGFloat, cutoutHeight ch: CGFloat) -> Path {
        var path = Path()
        // Topo reto, só a base com radius
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.maxY))
        path.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: 0))
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
