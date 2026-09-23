#!/usr/bin/env swift
//
// Draws the DMG window background: the night of the app icon, the notch with a line of script lit up under it, and
// an arrow from the app to the Applications folder. Writes a HiDPI TIFF (1x + 2x) for create-dmg.
//
// Run from the repo root:
//     swift scripts/generate-dmg-background.swift
//
// Output: scripts/dmg/background.tiff (the window is 640 x 400; icons sit at x 160 and 480, y 190)
//

import AppKit
import SwiftUI

private let orange = Color(red: 0.98, green: 0.45, blue: 0.09)

private struct Background: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.12, blue: 0.20), Color(red: 0.04, green: 0.04, blue: 0.07)],
                startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [orange.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0.1),
                           startRadius: 4, endRadius: 260)
            // The notch with a line of script under it, the current word glowing.
            VStack(spacing: 12) {
                UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16)
                    .fill(Color.black)
                    .frame(width: 150, height: 40)
                HStack(spacing: 6) {
                    Capsule().fill(Color.white.opacity(0.25)).frame(width: 40, height: 7)
                    Capsule().fill(orange).frame(width: 34, height: 9).shadow(color: orange, radius: 6)
                    Capsule().fill(Color.white.opacity(0.8)).frame(width: 52, height: 7)
                }
            }
            // Arrow between the two icons.
            Image(systemName: "arrow.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .offset(y: 170)
            Text(verbatim: "Drag Notchy to Applications")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .offset(y: 318)
        }
        .frame(width: 640, height: 400)
    }
}

@MainActor
private func image(scale: CGFloat) -> NSBitmapImageRep {
    let renderer = ImageRenderer(content: Background())
    renderer.scale = scale
    let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
    rep.size = NSSize(width: 640, height: 400)
    return rep
}

MainActor.assumeIsolated {
    let out = URL(fileURLWithPath: "scripts/dmg/background.tiff")
    let data = NSBitmapImageRep.tiffRepresentationOfImageReps(in: [image(scale: 1), image(scale: 2)],
                                                              using: .lzw, factor: 0)!
    try! data.write(to: out)
    print("Wrote \(out.path)")
}
