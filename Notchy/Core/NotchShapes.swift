import SwiftUI

/// Bottom edge is always rounded (docked into the top of the screen).
/// When collapsed, top corners are also rounded and an optional cutout avoids covering the camera notch.
struct NotchBarShape: Shape {
    /// When true (collapsed), top-left and top-right are rounded so the strip doesn't exceed the notch cutout.
    var roundTopCorners: Bool = false
    /// When set (collapsed + notch), a rounded rect is cut out at the top center so the bar doesn't cover the camera.
    var notchCutoutWidth: CGFloat?
    var notchCutoutHeight: CGFloat?

    private static let maxCornerRadius: CGFloat = 10
    private static let minCornerRadius: CGFloat = 4
    private static let collapsedBottomCornerRadius: CGFloat = 8
    /// Raio mínimo dos cantos inferiores quando recolhido, para não ficarem “quadrados” na faixa do notch.
    func path(in rect: CGRect) -> Path {
        var r = effectiveCornerRadius(for: rect)
        if roundTopCorners {
            let maxRByHeight = max(1, rect.height / 2 - 1)
            r = min(maxRByHeight, rect.width / 2 - 1)
            r = max(r, min(Self.collapsedBottomCornerRadius, rect.height - 1, rect.width / 2 - 1))
        }
        var path = Path()
        if roundTopCorners {
            let rTop = min(Self.maxCornerRadius, rect.width / 2 - 1, rect.height / 2 - 1)
            if let cw = notchCutoutWidth, let ch = notchCutoutHeight, cw > 0, ch > 0 {
                // Um único path em forma de moldura: contorno da barra com o recorte do notch integrado (sem winding).
                path = pathCollapsedBarWithNotchCutout(rect: rect, r: r, rTop: rTop, cutoutWidth: cw, cutoutHeight: ch)
            } else {
                // Início: topo esquerdo (após o raio do canto superior-esquerdo)
                path.move(to: CGPoint(x: rTop, y: 0))
                // Borda superior (até o canto superior-direito)
                path.addLine(to: CGPoint(x: rect.maxX - rTop, y: 0))
                // Canto superior-direito
                path.addArc(center: CGPoint(x: rect.maxX - rTop, y: rTop), radius: rTop, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
                // Borda direita (até o canto inferior-direito)
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
                // Canto inferior-direito
                path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
                // Borda inferior (até o canto inferior-esquerdo)
                path.addLine(to: CGPoint(x: r, y: rect.maxY))
                // Canto inferior-esquerdo
                path.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
                // Borda esquerda (até o canto superior-esquerdo)
                path.addLine(to: CGPoint(x: 0, y: rTop))
                // Canto superior-esquerdo
                path.addArc(center: CGPoint(x: rTop, y: rTop), radius: rTop, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
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

    /// Barra recolhida com contorno fechado suave (rounded rect, sem recorte do notch para evitar glitches).
    private func pathCollapsedBarWithNotchCutout(rect: CGRect, r: CGFloat, rTop: CGFloat, cutoutWidth cw: CGFloat, cutoutHeight ch: CGFloat) -> Path {
        var path = Path()
        // Mesmo path da barra recolhida sem cutout: contorno fechado suave (topo e base arredondados).
        path.move(to: CGPoint(x: rTop, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - rTop, y: 0))
        path.addArc(center: CGPoint(x: rect.maxX - rTop, y: rTop), radius: rTop, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: r, y: rect.maxY))
        path.addArc(center: CGPoint(x: r, y: rect.maxY - r), radius: r, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: rTop))
        path.addArc(center: CGPoint(x: rTop, y: rTop), radius: rTop, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
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
